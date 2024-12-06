// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {Position} from "v4-core/libraries/Position.sol";

import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";

// Make sure to update the interface when Stylus Contract's Solidity ABI changes.
interface IStylusDiamond {
    function getAmountInForExactOutput(uint256 amountOut, address input, address output, bool zeroForOne)
        external
        returns (uint256);

    function getAmountOutFromExactInput(uint256 amountIn, address input, address output, bool zeroForOne)
        external
        returns (uint256);
}

contract DiamondHook is BaseHook {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using SafeCast for uint256;
    using TickMath for int24;

    error AlreadyInitialized();
    error InvalidTickSpacing();
    error PoolNotOpen();
    error PriceOutOfBounds();
    error InsufficientHedgeCommitted();
    error OnlyModifyViaHook();

    uint24 internal constant _PIPS = 1000000;
    int24 public immutable lowerTick;
    int24 public immutable upperTick;
    int24 public immutable tickSpacing;
    uint24 public immutable baseBeta; // % expressed as uint < 1e6
    uint24 public immutable decayRate; // % expressed as uint < 1e6
    uint24 public immutable vaultRedepositRate; // % expressed as uint < 1e6

    uint256 public lastBlockOpened;
    uint256 public lastBlockReset;
    uint256 public hedgeRequired0;
    uint256 public hedgeRequired1;
    uint256 public hedgeCommitted0;
    uint256 public hedgeCommitted1;
    uint160 public committedSqrtPriceX96;
    PoolKey public poolKey;
    bool public initialized;

    struct PoolManagerCallData {
        uint256 amount; /// mintAmount | burnAmount | newSqrtPriceX96 (inferred from actionType)
        address msgSender;
        address receiver;
        uint8 actionType; /// 0 = mint | 1 = burn | 2 = arbSwap
    }

    IStylusDiamond _stylusDiamondContract;

    constructor(
        IPoolManager _poolManager,
        address _stylusDiamondContractAddress,
        int24 _tickSpacing,
        uint24 _baseBeta,
        uint24 _decayRate,
        uint24 _vaultRedepositRate
        ) BaseHook(_poolManager) {
        _stylusDiamondContract = IStylusDiamond(_stylusDiamondContractAddress);
        lowerTick = _tickSpacing.minUsableTick();
        upperTick = _tickSpacing.maxUsableTick();
        tickSpacing = _tickSpacing;
        require(
            _baseBeta < _PIPS &&
            _decayRate <= _baseBeta &&
            _vaultRedepositRate < _PIPS  
        );
        baseBeta = _baseBeta;
        decayRate = _decayRate;
        vaultRedepositRate = _vaultRedepositRate;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function beforeInitialize(
        address,
        PoolKey calldata poolKey_,
        uint160 sqrtPriceX96
    ) external override returns (bytes4) {
        /// can only initialize one pool once.
        if (initialized) revert AlreadyInitialized();
        /// validate tick bounds on pool initialization
        if (poolKey_.tickSpacing != tickSpacing) revert InvalidTickSpacing();

        /// initialize state variable
        poolKey = poolKey_;
        lastBlockOpened = block.number - 1;
        lastBlockReset = block.number;
        committedSqrtPriceX96 = sqrtPriceX96;
        initialized = true;

        return this.beforeInitialize.selector;
    }

    function beforeSwap(
        address sender,
        PoolKey calldata, 
        IPoolManager.SwapParams calldata, 
        bytes calldata
    ) external view override returns (bytes4, BeforeSwapDelta, uint24) {
        /// if swap is coming from the hook then its a 1 wei swap to kick the price and not a "normal" swap
        if (sender != address(this)) {
            /// disallow normal swaps at top of block
            if (lastBlockOpened != block.number) revert PoolNotOpen();
        }
        return (
            this.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            0 // no fee, todo: check again
        );
    }

    function afterSwap(
        address sender, 
        PoolKey calldata, 
        IPoolManager.SwapParams calldata, 
        BalanceDelta, 
        bytes calldata
    ) external override returns (bytes4, int128) {
         /// if swap is coming from the hook then its a 1 wei swap to kick the price and not a "normal" swap
        if (sender != address(this)) {
            /// cannot move price to edge of LP position
            PoolId poolId = PoolIdLibrary.toId(poolKey);
            (uint160 sqrtPriceX96, , , ) = poolManager.getSlot0(poolId);
            uint160 sqrtPriceX96Lower = TickMath.getSqrtPriceAtTick(lowerTick);
            uint160 sqrtPriceX96Upper = TickMath.getSqrtPriceAtTick(upperTick);
            if (
                sqrtPriceX96 >= sqrtPriceX96Upper ||
                sqrtPriceX96 <= sqrtPriceX96Lower
            ) revert PriceOutOfBounds();

            /// Uniswap uses a combination of the pair token addresses as the salt, and the bytecode is always the same.
            bytes32 salt = 0x1234567890123456789012345678901234567890123456789012345678901234;
            // todo: change hard code above to this keccak256(abi.encodePacked(token0, token1));
            (uint128 liquidity, ,) = poolManager.getPositionInfo(poolId, address(this), lowerTick, upperTick, salt);

            (uint256 current0, uint256 current1) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    sqrtPriceX96Lower,
                    sqrtPriceX96Upper,
                    liquidity
                );

            (uint256 need0, uint256 need1) = LiquidityAmounts
                .getAmountsForLiquidity(
                    committedSqrtPriceX96,
                    sqrtPriceX96Lower,
                    sqrtPriceX96Upper,
                    liquidity
                );

            if (need0 > current0) {
                uint256 min0 = need0 - current0;
                if (min0 > hedgeCommitted0) revert InsufficientHedgeCommitted();
                hedgeRequired0 = min0;
                hedgeRequired1 = 0;
            } else if (need1 > current1) {
                uint256 min1 = need1 - current1;
                if (min1 > hedgeCommitted1) revert InsufficientHedgeCommitted();
                hedgeRequired1 = min1;
                hedgeRequired0 = 0;
            } else {
                hedgeRequired0 = 0;
                hedgeRequired1 = 0;
            }

        }
        return (this.afterSwap.selector, 0); // no fee, todo: check again
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external view override returns (bytes4) {
        /// force LPs to provide/withdraw liquidity through hook
        if (sender != address(this)) revert OnlyModifyViaHook();
        return this.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external view override returns (bytes4) {
        /// force LPs to provide/withdraw liquidity through hook
        if (sender != address(this)) revert OnlyModifyViaHook();
        return this.beforeRemoveLiquidity.selector;
    }

    
}
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
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using SafeCast for uint256;
    using TickMath for int24;

    uint24 internal constant _PIPS = 1000000;
    int24 public immutable lowerTick;
    int24 public immutable upperTick;
    int24 public immutable tickSpacing;
    uint24 public immutable baseBeta; // % expressed as uint < 1e6
    uint24 public immutable decayRate; // % expressed as uint < 1e6
    uint24 public immutable vaultRedepositRate; // % expressed as uint < 1e6

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



    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // You can add, modify, or delete the logic here if needed.

        bool exactInput = params.amountSpecified < 0;
        (Currency specified, Currency unspecified) =
            (params.zeroForOne == exactInput) ? (key.currency0, key.currency1) : (key.currency1, key.currency0);

        uint256 specifiedAmount = exactInput ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);
        uint256 unspecifiedAmount;

        BeforeSwapDelta returnDelta;

        if (exactInput) {
            unspecifiedAmount = _stylusDiamondContract.getAmountOutFromExactInput(
                specifiedAmount, Currency.unwrap(specified), Currency.unwrap(unspecified), params.zeroForOne
            );

            returnDelta = toBeforeSwapDelta(specifiedAmount.toInt128(), -unspecifiedAmount.toInt128());
        } else {
            unspecifiedAmount = _stylusDiamondContract.getAmountInForExactOutput(
                specifiedAmount, Currency.unwrap(unspecified), Currency.unwrap(specified), params.zeroForOne
            );

            returnDelta = toBeforeSwapDelta(-specifiedAmount.toInt128(), unspecifiedAmount.toInt128());
        }

        
    }

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4, int128)
    {
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
    }
}
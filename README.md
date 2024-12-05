Common dev commands
===================
```

cargo stylus --help

cargo stylus check

cargo stylus deploy \
  --endpoint='http://localhost:8547' \
  --private-key="0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659" \
  --estimate-gas

cargo stylus deploy --private-key=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 -e=http://localhost:8547 --no-verify

cargo stylus export-abi -> for hooks to call

cast call --rpc-url 'http://localhost:8547' --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 \
[deployed-contract-address] "number()(uint256)"

cast send --rpc-url 'http://localhost:8547' --private-key 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659 \
[deployed-contract-address] "increment()"
```

test node prefunded account: 
1. 0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659
2. ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
pre-funded dev account: 0x3f1eae7d46d88f08fc2f8ed27fcb2ab183eb2d0e

hook calling curve: https://github.com/OpenZeppelin/uniswap-solidity-hooks-template; https://github.com/OpenZeppelin/uniswap-solidity-hooks-template/blob/main/src/Counter.sol
forge test is calling a mock curve contract

curve template: https://github.com/OpenZeppelin/uniswap-stylus-curve-template/blob/main/src/lib.rs
sdk:https://docs.arbitrum.io/stylus/reference/overview
by example:https://stylus-by-example.org/
debug errors: https://github.com/OffchainLabs/cargo-stylus/blob/main/main/VALID_WASM.md


ref:
https://ethresear.ch/t/lvr-minimization-in-uniswap-v4/15900
https://fenbushi.vc/2024/01/20/ending-lps-losing-game-exploring-the-loss-versus-rebalancing-lvr-problem-and-its-solutions/



Logic of hook
==============================================================================

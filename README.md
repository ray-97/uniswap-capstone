Credits & references:
==============================================================================
1. https://mirror.xyz/0x929fCf268A62e684221f1e39B8b6ddA2f0dA4AeC/ZhTQJ6qiurBTHBNuF08GudWBQ8x9p3P-12vo-C9czKE
2. https://github.com/ArrakisFinance/minimize-lvr-hook-poc (implementation by: Arrakis Fi Team and @The-CTra1n)
3. https://youtu.be/q5vyJJb-Uyw?si=tndrq71Uk6kQk2ie
4. https://youtu.be/XmHBiFApDXA?si=R_w3VN1VlNjgz4N6
5. https://youtu.be/ja3HPbkgaIY?si=i1LDxSEL043xbNeC
6. https://ethresear.ch/t/lvr-minimization-in-uniswap-v4/15900
7. https://fenbushi.vc/2024/01/20/ending-lps-losing-game-exploring-the-loss-versus-rebalancing-lvr-problem-and-its-solutions/

hook calling curve: https://github.com/OpenZeppelin/uniswap-solidity-hooks-template; https://github.com/OpenZeppelin/uniswap-solidity-hooks-template/blob/main/src/Counter.sol
forge test is calling a mock curve contract

curve template: https://github.com/OpenZeppelin/uniswap-stylus-curve-template/blob/main/src/lib.rs
sdk:https://docs.arbitrum.io/stylus/reference/overview
by example:https://stylus-by-example.org/
debug errors: https://github.com/OffchainLabs/cargo-stylus/blob/main/main/VALID_WASM.md


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
0xb6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659
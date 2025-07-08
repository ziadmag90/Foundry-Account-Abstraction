// SPDX-License-Identifier:MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {ERC20Mock} from "@openzeppelin-contracts/mocks/token/ERC20Mock.sol";

contract CodeConstant {
    // Chain ID for the Ethereum Sepolia testnet.
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;

    // Chain ID for the zkSync Sepolia testnet.
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;

    // Chain ID for the Arbitrum Sepolia testnet.
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

    // Chain ID for a local development blockchain.
    uint256 constant LOCAL_CHAIN_ID = 31337;

    // Address of a designated burner wallet where funds can be sent and will not be retrieved.
    address constant BURNER_WALLET = 0xf52205F70531e62f7199D3f3835FDdCd86791294;

    // Default wallet address used by the Foundry framework for development purposes.
    address constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    // Default private key used by Anvil
    uint256 constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // Default address of the first funded account provided by Anvil for local testing
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
}

contract HelperConfig is Script, CodeConstant {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
        address usdc; // USDC address for the network, if applicable
    }

    NetworkConfig public localNetworkConfig;

    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZksyncSepoliaConfig();
        networkConfigs[ARBITRUM_SEPOLIA_CHAIN_ID] = getArbitrumSepoliaConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainid(block.chainid);
    }

    function getConfigByChainid(uint256 chainid) public returns (NetworkConfig memory) {
        if (chainid == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainid].account != address(0)) {
            return networkConfigs[chainid];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108,
            account: BURNER_WALLET,
            usdc: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 // USDC address on Sepolia
        });
    }

    function getZksyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0),
            account: BURNER_WALLET,
            usdc: 0xAe045DE5638162fa134807Cb558E15A3F5A7F853
        });
    }

    function getArbitrumSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108,
            account: BURNER_WALLET,
            usdc: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        // depoly mocks
        console2.log("Deploying mocks...");
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entrypoint = new EntryPoint();
        ERC20Mock usdc = new ERC20Mock();
        vm.stopBroadcast();

        localNetworkConfig =
            NetworkConfig({entryPoint: address(entrypoint), account: ANVIL_DEFAULT_ACCOUNT, usdc: address(usdc)});
        return localNetworkConfig;
    }
}

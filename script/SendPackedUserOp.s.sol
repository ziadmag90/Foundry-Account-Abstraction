// SPDX-License-Identifier:MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {HelperConfig, CodeConstant} from "./HelperConfig.s.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {DevOpsTools} from "foundry-devops/DevOpsTools.sol";

contract SendPackedUserOp is Script, CodeConstant {
    function run() external {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.getConfig();

        address dest = config.usdc;
        uint256 value = 0;
        bytes memory functionData =
            abi.encodeWithSelector(IERC20.transfer.selector, 0x0178157cdFE53CE7Ee4c937928e6746ab68952b8, 1e6); // not 1e18
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        address minimalAccount = DevOpsTools.get_most_recent_deployment("MinimalAccount", block.chainid);

        // Transaction Hash success on arbitrum : 0xed270e0016df0fe322e1b97cf9acb8caf861502783beb9270f874761e2c684a6
        // address minimalAccount = 0xdCe0f65638D3860065E68393b25b5f4917773ef1;

        PackedUserOperation memory UserOp = generatedSignedUserOperation(executeCallData, config, minimalAccount);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = UserOp;

        vm.startBroadcast();
        IEntryPoint(config.entryPoint).handleOps(ops, payable(config.account));
        vm.stopBroadcast();
    }

    function generatedSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // Generate the unsigned data
        uint256 nonce = IEntryPoint(config.entryPoint).getNonce(minimalAccount, uint192(0));
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);

        // Get the userOp Hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        // Sign it and return it
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (block.chainid == LOCAL_CHAIN_ID) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 150_000;
        uint128 callGasLimit = 100_000;
        uint128 maxPriorityFeePerGas = 1_000_000_000;
        uint128 maxFeePerGas = 2_000_000_000;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}

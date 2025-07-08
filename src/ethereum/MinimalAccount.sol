//SPDX-License-Identifier:MIT
pragma solidity ^0.8.30;

import {IAccount, PackedUserOperation} from "account-abstraction/interfaces/IAccount.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/core/Helpers.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

    IEntryPoint private immutable i_entryPoint;

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    function execute(address dest, uint256 amount, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: amount}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }
    // A signature is valid, if it's the MinimalAccount owner

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);

        _payPreFund(missingAccountFunds);
    }
    // EIP-191 version of the signed hash

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256)
    {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(digest, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPreFund(uint256 missingAccountFund) internal {
        if (missingAccountFund != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFund, gas: type(uint256).max}("");
            (success);
        }
    }

    // Getter
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}

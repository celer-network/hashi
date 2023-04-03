// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.17;

import "../BlockHashOracleAdapter.sol";
import "./safeguard/MessageAppPauser.sol";

interface IMessageReceiverApp {
    enum ExecutionStatus {
        Fail, // execution failed, finalized
        Success, // execution succeeded, finalized
        Retry // execution rejected, can retry later
    }

    /**
     * @notice Called by MessageBus to execute a message
     * @param _sender The address of the source app contract
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);
}

contract CelerAdapter is IMessageReceiverApp, MessageAppPauser, BlockHashOracleAdapter {
    address public immutable msgBus;
    mapping(uint256 => address) public reporters;
    mapping(bytes32 => bool) public executedMessages;

    event ReportersUpdated(uint256 srcChainId, address reporter);

    modifier onlyMessageBus() {
        require(msg.sender == msgBus, "caller is not message bus");
        _;
    }

    constructor(address _msgBus) {
        msgBus = _msgBus;
    }

    // Called by MessageBus on destination chain to receive cross-chain messages.
    // The message is abi.encode of (uint256[] ids, bytes32[] hashes).
    function executeMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus whenNotMsgPaused returns (ExecutionStatus) {
        (bytes32 msgId, uint256[] memory ids, bytes32[] memory hashes) = abi.decode(
            _message,
            (bytes32, uint256[], bytes32[])
        );
        require(!executedMessages[msgId], "already executed message");
        executedMessages[msgId] = true;
        require(_srcContract == reporters[_srcChainId], "not allowed reporter");
        require(ids.length == hashes.length, "mismatch length");
        for (uint256 i; i < ids.length; ++i) {
            _storeHash(uint256(_srcChainId), ids[i], hashes[i]);
        }
        return ExecutionStatus.Success;
    }

    /**
     * @notice Update hash reporter on src chain.
     * @param _srcChainIds The chain Ids of _reporters.
     * @param _reporters Addresses of reporters that needs to be updated.
     */
    function updateReporter(uint256[] calldata _srcChainIds, address[] calldata _reporters) external onlyOwner {
        require(_srcChainIds.length == _reporters.length, "mismatch length");
        for (uint256 i; i < _srcChainIds.length; ++i) {
            reporters[_srcChainIds[i]] = _reporters[i];
            emit ReportersUpdated(_srcChainIds[i], _reporters[i]);
        }
    }
}

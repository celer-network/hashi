// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../interfaces/IMessageBus.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BaseMessageSender is OwnableUpgradeable {
    IMessageBus public immutable msgBus;
    // dstChainId => receiverAdapter address
    mapping(uint256 => address) public receiverAdapters;
    uint256 public nonce;

    event ReceiverAdapterUpdated(uint256 dstChainId, address receiverAdapter);

    constructor(address _msgBus) {
        msgBus = IMessageBus(_msgBus);
    }

    function updateReceiverAdapter(
        uint256[] calldata _dstChainIds,
        address[] calldata _receiverAdapters
    ) external onlyOwner {
        require(_dstChainIds.length == _receiverAdapters.length, "mismatch length");
        for (uint256 i; i < _dstChainIds.length; ++i) {
            _updateReceiverAdapter(_dstChainIds[i], _receiverAdapters[i]);
        }
    }

    function _getMessageFee(bytes calldata _data) internal view returns (uint256) {
        // fee is depended only on message length
        return msgBus.calcFee(_data);
    }

    function _sendMessage(uint256 _toChainId, bytes memory _data) internal {
        require(receiverAdapters[_toChainId] != address(0), "no receiver adapter");
        msgBus.sendMessage{ value: msg.value }(receiverAdapters[_toChainId], _toChainId, _data);
    }

    function _updateReceiverAdapter(uint256 _dstChainId, address _receiverAdapter) internal {
        receiverAdapters[_dstChainId] = _receiverAdapter;
        emit ReceiverAdapterUpdated(_dstChainId, _receiverAdapter);
    }

    function _getNewMessageId(uint256 _toChainId) internal returns (bytes32 messageId) {
        messageId = keccak256(
            abi.encodePacked(getChainId(), _toChainId, nonce, address(this), receiverAdapters[_toChainId])
        );
        nonce++;
    }

    /// @dev Get current chain id
    function getChainId() public view virtual returns (uint256 cid) {
        assembly {
            cid := chainid()
        }
    }
}

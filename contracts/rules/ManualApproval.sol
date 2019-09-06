pragma solidity ^0.5.0;

import "./ITransferRestriction.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../token/ISRC20.sol";

// owner should be authority role in SRC20
contract ManualApproval is ITransferRestriction, Ownable {
    struct TransferRequest {
        address from;
        address to;
        uint256 value;
    }

    uint256 private _reqNumber;
    ISRC20 private src; // move to aggregator...

    mapping(uint256 => TransferRequest) private _transferReq;
    mapping(address => bool) private _grayList;

    event TransferRequest(
        uint256 indexed requestNumber,
        address indexed from,
        address indexed to,
        uint256 value
    );

    event TransferApproval(
        uint256 indexed requestNumber,
        address indexed from,
        address indexed to,
        address value
    );

    constructor () {
        _reqNumber = 0;
    }

    /**
    * @dev ...
    *
    */
    function transferRequest(address from, address to, uint256 value) external returns (bool) {// where to transfer funds to this contract???
        if (!(_grayList[from] || _grayList[to])) {
            return false;
        }

        src.completeTransfer(from, address(this), value); //ERC20 transfer() no from...

        _transferReq[_reqNumber] = new TransferRequest(
            from,
            to,
            value
        );

        emit TransferRequest(_reqNumber, from, to, value);
        _reqNumber = _reqNumber + 1;

        return true;
    }

    function transferApproval(uint256 reqNumber) external onlyOwner returns (bool) {
        TransferRequest req = _transferReq[reqNumber];

        src.completeTransfer(address(this), req.to, value);

        delete _transferReq[reqNumber];
        emit TransferApproval(reqNumber, req.from, req.to, req.value);
        return true;
    }

    function cancelTransferRequest(uint256 reqNumber) external returns (bool) {
        TransferRequest req = _transferReq[reqNumber];
        require(req.from == msg.sender, "Not owner of the transfer request");

        src.completeTransfer(address(this), req.from, req.value);

        delete _transferReq[reqNumber];
        emit TransferRequestCanceled(reqNumber, req.from, req.to, req.value);

        return true;
    }

    // Handling gray listing
    function grayListedAccount(address account) external onlyOwner {
        _grayList[account] = true;
    }

    function unGrayListedAccount(address account) external onlyOwner {
        _grayList[account] = false;
    }
}

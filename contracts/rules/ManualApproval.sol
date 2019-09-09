pragma solidity ^0.5.0;

import "./ITransferRestriction.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../token/ISRC20.sol";

// owner should be authority role in SRC20
contract ManualApproval is Ownable {
    struct TransferReq {
        address from;
        address to;
        uint256 value;
    }

    uint256 private _reqNumber;
    ISRC20 private _src20; // move to aggregator...

    mapping(uint256 => TransferReq) private _transferReq;
    mapping(address => bool) private _grayList;

    event TransferRequest(
        uint256 indexed requestNumber,
        address from,
        address to,
        uint256 value
    );

    event TransferApproval(
        uint256 indexed requestNumber,
        address indexed from,
        address indexed to,
        uint256 value
    );

    event TransferRequestCanceled(
        uint256 indexed requestNumber,
        address indexed from,
        address indexed to,
        uint256 value
    );

    constructor () public {
    }

    /**
    * @dev ...
    *
    */
    function _transferRequest(address from, address to, uint256 value) internal returns (bool) {
        if (!(_grayList[from] || _grayList[to])) {
            return false;
        }

        _src20.executeTransfer(from, address(this), value);

        _transferReq[_reqNumber] = TransferReq(from, to, value);

        emit TransferRequest(_reqNumber, from, to, value);
        _reqNumber = _reqNumber + 1;

        return true;
    }

    function transferApproval(uint256 reqNumber) external onlyOwner returns (bool) {
        TransferReq memory req = _transferReq[reqNumber];

        _src20.executeTransfer(address(this), req.to, req.value);

        delete _transferReq[reqNumber];
        emit TransferApproval(reqNumber, req.from, req.to, req.value);
        return true;
    }

    function cancelTransferRequest(uint256 reqNumber) external returns (bool) {
        TransferReq memory req = _transferReq[reqNumber];
        require(req.from == msg.sender, "Not owner of the transfer request");

        _src20.executeTransfer(address(this), req.from, req.value);

        delete _transferReq[reqNumber];
        emit TransferRequestCanceled(reqNumber, req.from, req.to, req.value);

        return true;
    }

    // Handling gray listing
    function isGrayListed(address account) public view returns (bool){
        return _grayList[account];
    }

    function grayListedAccount(address account) external onlyOwner returns (bool){
        _grayList[account] = true;
        return true;
    }

    function unGrayListedAccount(address account) external onlyOwner returns (bool){
        delete _grayList[account];
        return true;
    }
}

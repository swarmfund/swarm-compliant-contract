pragma solidity ^0.5.0;

import "../interfaces/ITransferRules.sol";
import "../interfaces/ISRC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/*
 * @title ManualApproval contract
 * @dev On-chain transfer rule that is handling transfer request/execution for
 * grey-listed account
 */
contract ManualApproval is Ownable {
    struct TransferReq {
        address from;
        address to;
        uint256 value;
    }

    uint256 public _reqNumber;
    ISRC20 public _src20;

    mapping(uint256 => TransferReq) public _transferReq;
    mapping(address => bool) public _greyList;

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
     * @dev Owner of this contract have authority to approve tx which are valid.
     *
     * @param reqNumber - transfer request number.
     */
    function transferApproval(uint256 reqNumber) external onlyOwner returns (bool) {
        TransferReq memory req = _transferReq[reqNumber];

        require(_src20.executeTransfer(address(this), req.to, req.value), "SRC20 transfer failed");

        delete _transferReq[reqNumber];
        emit TransferApproval(reqNumber, req.from, req.to, req.value);
        return true;
    }

    /**
     * @dev Canceling transfer request and returning funds to from.
     *
     * @param reqNumber - transfer request number.
     */
    function cancelTransferRequest(uint256 reqNumber) external returns (bool) {
        TransferReq memory req = _transferReq[reqNumber];
        require(req.from == msg.sender, "Not owner of the transfer request");

        require(_src20.executeTransfer(address(this), req.from, req.value), "SRC20: External transfer failed");

        delete _transferReq[reqNumber];
        emit TransferRequestCanceled(reqNumber, req.from, req.to, req.value);

        return true;
    }

    // Handling grey listing
    function isGreyListed(address account) public view returns (bool){
        return _greyList[account];
    }

    function greyListAccount(address account) external onlyOwner returns (bool) {
        _greyList[account] = true;
        return true;
    }

    function bulkGreyListAccount(address[] calldata accounts) external onlyOwner returns (bool) {
        for (uint256 i = 0; i < accounts.length ; i++) {
            address account = accounts[i];
            _greyList[account] = true;
        }
        return true;
    }

    function unGreyListAccount(address account) external onlyOwner returns (bool) {
        delete _greyList[account];
        return true;
    }

    function bulkUnGreyListAccount(address[] calldata accounts) external onlyOwner returns (bool) {
        for (uint256 i = 0; i < accounts.length ; i++) {
            address account = accounts[i];
            delete _greyList[account];
        }
        return true;
    }

    function _transferRequest(address from, address to, uint256 value) internal returns (bool) {
        require(_src20.executeTransfer(from, address(this), value), "SRC20 transfer failed");

        _transferReq[_reqNumber] = TransferReq(from, to, value);

        emit TransferRequest(_reqNumber, from, to, value);
        _reqNumber = _reqNumber + 1;

        return true;
    }
}

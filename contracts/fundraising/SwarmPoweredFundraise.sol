pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraise {

    using SafeMath for uint256;

    string public label;
    address public src20;
    uint256 public tokenAmount;
    uint256 public startDate;
    uint256 public endDate;
    uint256 public softCap;
    uint256 public hardCap;
    address public baseCurrency;

    uint256 public tokenPriceBCY;
    uint256 public totalTokenAmount;
    // array

    constructor(
        string memory _label,
        address _src20,
        uint256 _tokenAmount,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _softCap,
        uint256 _hardCap,
        address _baseCurrency
    ) public {
        label = _label;
        src20 = _src20;
        tokenAmount = _tokenAmount;
        startDate = _startDate;
        endDate = _endDate;
        softCap = _softCap;
        hardCap = _hardCap;
        baseCurrency = _baseCurrency;
    }

    function () external payable {
    }

    function setTokenPriceBCY(uint256 _tokenPriceBCY) external returns (bool) {
        return true;
    }

    function setTotalTokenAmount(uint256 _totalTokenAmount) external returns (bool) {
        return true;
    }

    function contribute(address erc20, uint256 amount) public returns (bool) {
        return true;
    }

    function acceptContribution(address contributor, address erc20, uint256 amount) external returns (bool) {
        return true;
    }

    function rejectContribution(address contributor, address erc20, uint256 amount) external returns (bool) {
        return true;
    }

    function withdrawInvestmentETH() external returns (bool) {
        return true;
    }

    function withdrawInvestmentToken() external returns (bool) {
        return true;
    }

    function finishFundraising() external returns (bool) {
        return true;
    }
}
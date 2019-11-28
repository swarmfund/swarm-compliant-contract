pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./SwarmPoweredFundraise.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraiseMock is SwarmPoweredFundraise {

    using SafeMath for uint256;
    // array

    constructor(
        string memory _label,
        address _src20,
        address _currencyRegistry,
        uint256 _SRC20tokenSupply,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _softCapBCY,
        uint256 _hardCapBCY
    )
    SwarmPoweredFundraise
    (
        _label,
        _src20,
        _currencyRegistry,
        _SRC20tokenSupply,
        _startDate,
        _endDate,
        _softCapBCY,
        _hardCapBCY
    )
    public
    {
    }

    function getBalanceETH(address contributor) public view returns (uint256) {
        return qualifiedContributions[contributor][address(0)] + 
               bufferedContributions[contributor][address(0)];
    }

    function getBalanceToken(address contributor, address token) public view returns (uint256) {
        return qualifiedContributions[contributor][token] + 
               bufferedContributions[contributor][token];
    }

    function getBalanceETHTotal() public view returns (uint256) {
        return qualifiedSums[address(0)] + bufferedSums[address(0)];
    }

    function getBalanceTokenTotal(address token) public view returns (uint256) {
        return qualifiedSums[token] + bufferedSums[token];
    }

    function acceptContribution(address contributor, uint256 sequence) external returns (bool) {
        return true;
    }

    function rejectContribution(address contributor, uint256 sequence) external returns (bool) {
        return true;
    }
}
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./SwarmPoweredFundraise.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraiseFinished is SwarmPoweredFundraise {

    using SafeMath for uint256;
    // array

    bool isOngoing = false;
    bool isFinished = true;

    constructor(
        string memory _label,
        address _src20,
        uint256 _tokenAmount,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _softCap,
        uint256 _hardCap,
        address _baseCurrency)
        SwarmPoweredFundraise(
            _label,
            _src20,
            _tokenAmount,
            _startDate,
            _endDate,
            _softCap,
            _hardCap,
            _baseCurrency
            )
        public
    {
    }

    function () external payable {
        revert();
    }

    function getBalanceETH(address contributor) public view returns (uint256) {
        return 0;
    }

    function getBalanceToken(address token, uint256 amount) public view returns (uint256) {
        return 0;
    }

    function claimTokens() public view returns (uint256) {
        return 0;
    }
}
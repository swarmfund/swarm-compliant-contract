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

    function getBalanceETH(address contributor) public view returns (uint256) {
        return 0;
    }

    function getBalanceToken(address token, uint256 amount) public view returns (uint256) {
        return 0;
    }
}
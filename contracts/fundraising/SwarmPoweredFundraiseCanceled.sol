pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./SwarmPoweredFundraise.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraiseCanceled is SwarmPoweredFundraise {

    using SafeMath for uint256;
    // array

    function () external payable {
        revert();
    }
}
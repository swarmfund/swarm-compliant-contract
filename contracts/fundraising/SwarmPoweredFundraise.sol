pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraise {

    using SafeMath for uint256;
    // array

    function () external payable {
    }

    function contribute(address erc20, uint256 amount) public returns (bool) {
        return true;
    }
}
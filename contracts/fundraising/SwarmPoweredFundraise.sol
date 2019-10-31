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
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/**
 * @title SwarmToken mock contract.
 */
contract SwarmTokenMock is ERC20 {
    uint256 public constant decimals = 18;
    string public constant name = "Swarm Mock Token";
    string public constant symbol = "SWM";

    constructor(address initialAccount, uint256 initialBalance) public {
        _mint(initialAccount, initialBalance);
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Manager handles SRC20 burn/mint in relation to
 * SWM token staking.
 */
interface IManager {
 
    event SRC20SupplyMinted(address src20, address swmAccount, uint256 swmValue, uint256 src20Value);
    event SRC20StakeIncreased(address src20, address swmAccount, uint256 swmValue);
    event SRC20StakeDecreased(address src20, address swmAccount, uint256 swmValue);

    function mintSupply(address src20, address swmAccount, uint256 swmValue, uint256 src20Value) external returns (bool);
    function incStake(address src20, address swmAccount, uint256 swmValue) external returns (bool);
    function decStake(address src20, address swmAccount, uint256 swmValue) external returns (bool);
    function renounceManagement(address src20) external returns (bool);
    function transferManagement(address src20, address newManager) external returns (bool);
    function calcTokens(address src20, uint256 swmValue) external view returns (uint256);
}

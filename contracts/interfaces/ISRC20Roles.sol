pragma solidity ^0.5.0;

/**
 * @dev Contract module which allows children to implement access managements
 * with multiple roles.
 *
 * `Authority` the one how is authorized by token owner/issuer to authorize transfers
 * either on-chain or off-chain.
 *
 * `Delegate` the person who person responsible for updating KYA document
 *
 * `Manager` the person who is responsible for minting and burning the tokens. It should be
 * be registry contract where staking->minting is executed.
 */
contract ISRC20Roles {
    function isAuthority(address account) external view returns (bool);
    function removeAuthority(address account) external returns (bool);
    function addAuthority(address account) external returns (bool);

    function isDelegate(address account) external view returns (bool);
    function addDelegate(address account) external returns (bool);
    function removeDelegate(address account) external returns (bool);

    function manager() external view returns (address);
    function isManager(address account) external view returns (bool);
    function transferManagement(address newManager) external returns (bool);
    function renounceManagement() external returns (bool);
}
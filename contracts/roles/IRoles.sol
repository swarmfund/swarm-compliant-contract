pragma solidity ^0.5.0;

contract IRoles {
    function isAuthority(address account) external view returns (bool);
    function removeAuthority(address account) external;
    function addAuthority(address account) external;

    function isDelegate(address account) external view returns (bool);
    function addDelegate(address account) external;
    function removeDelegate(address account) external;

    function manager() external view returns (address);
    function isManager(address account) public view returns (bool);
    function transferManagement(address newManager) external returns (bool);
    function renounceManagement() external returns (bool);
}
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ISRC20.sol";
import "../interfaces/ISRC20Managed.sol";
import "../interfaces/ISRC20Roles.sol";
import "../interfaces/IManager.sol";


/**
 * @dev Manager handles SRC20 burn/mint in relation to
 * SWM token staking.
 */
contract Manager is IManager, Ownable {
    using SafeMath for uint256;

    event SRC20SupplyMinted(address src20, address swmAccount, uint256 swmValue, uint256 src20Value);
    event SRC20SupplyIncreased(address src20, address swmAccount, uint256 srcValue);
    event SRC20SupplyDecreased(address src20, address swmAccount, uint256 srcValue);

    mapping (address => SRC20) internal _registry;

    struct SRC20 {
        address owner;
        address roles;
        uint256 stake;
        address minter;
    }

    IERC20 private _swmERC20;

    constructor(address swmERC20) public {
        require(swmERC20 != address(0), 'SWM ERC20 is zero address');

        _swmERC20 = IERC20(swmERC20);
    }

    modifier onlyTokenOwner(address src20) {
        require(_isTokenOwner(src20), "Caller not token owner.");
        _;
    }

    // Note that, similarly to the role of token owner, there is only one manager per src20 token contract.
    // Only one address can have this role.
    modifier onlyMinter(address src20) {
        require(msg.sender == _registry[src20].minter, "Caller not token minter.");
        _;
    }

    /**
     * @dev Mint additional supply of SRC20 tokens based on SWN token stake.
     * Can be used for initial supply and subsequent minting of new SRC20 tokens.
     * When used, Manager will update SWM/SRC20 values in this call and use it
     * for token owner's incStake/decStake calls, minting/burning SRC20 based on
     * current SWM/SRC20 ratio.
     * Only owner of this contract can invoke this method. Owner is SWARM controlled
     * address.
     * Emits SRC20SupplyMinted event.
     *
     * @param src20 SRC20 token address.
     * @param swmAccount SWM ERC20 account holding enough SWM tokens (>= swmValue)
     * with manager contract address approved to transferFrom.
     * @param swmValue SWM stake value.
     * @param src20Value SRC20 tokens to mint
     * @return true on success.
     */
    function mintSupply(address src20, address swmAccount, uint256 swmValue, uint256 src20Value)
        onlyMinter(src20)
        external
        returns (bool)
    {
        require(swmAccount != address(0), "SWM account is zero");
        require(swmValue != 0, "SWM value is zero");
        require(src20Value != 0, "SRC20 value is zero");
        require(_registry[src20].owner != address(0), "SRC20 token contract not registered");

        _registry[src20].stake = _registry[src20].stake.add(swmValue);

        require(_swmERC20.transferFrom(swmAccount, address(this), swmValue));
        require(ISRC20Managed(src20).mint(_registry[src20].owner, src20Value));

        emit SRC20SupplyMinted(src20, swmAccount, swmValue, src20Value);

        return true;
    }

    /**
     * @dev This is function token issuer can call in order to increase his SRC20 supply this
     * and stake his tokens.
     *
     * @param src20 Address of src20 token contract
     * @param swmAccount Account from which stake tokens are going to be deducted
     * @param srcValue Value of desired SRC20 token value
     * @return true if success
     */
    function increaseSupply(address src20, address swmAccount, uint256 srcValue)
        external
        onlyTokenOwner(src20)
        returns (bool)
    {
        require(swmAccount != address(0), "SWM account is zero");
        require(srcValue != 0, "SWM value is zero");
        require(_registry[src20].owner != address(0), "SRC20 token contract not registered");

        uint256 swmValue = _swmNeeded(src20, srcValue);

        require(_swmERC20.transferFrom(swmAccount, address(this), swmValue));
        require(ISRC20Managed(src20).mint(_registry[src20].owner, srcValue));

        _registry[src20].stake = _registry[src20].stake.add(swmValue);
        emit SRC20SupplyIncreased(src20, swmAccount, swmValue);

        return true;
    }

    /**
     * @dev This is function token issuer can call in order to decrease his SRC20 supply
     * and his stake back
     *
     * @param src20 Address of src20 token contract
     * @param swmAccount Account to which stake tokens will be returned
     * @param srcValue Value of desired SRC20 token value
     * @return true if success
     */
    function decreaseSupply(address src20, address swmAccount, uint256 srcValue)
        external
        onlyTokenOwner(src20)
        returns (bool)
    {
        require(swmAccount != address(0), "SWM account is zero");
        require(srcValue != 0, "SWM value is zero");
        require(_registry[src20].owner != address(0), "SRC20 token contract not registered");

        uint256 swmValue = _swmNeeded(src20, srcValue);

        require(_swmERC20.transfer(swmAccount, swmValue));
        require(ISRC20Managed(src20).burn(_registry[src20].owner, srcValue));

        _registry[src20].stake = _registry[src20].stake.sub(swmValue);
        emit SRC20SupplyDecreased(src20, swmAccount, srcValue);

        return true;
    }

    /**
     * @dev Allows manager to renounce management.
     *
     * @param src20 SRC20 token address.
     * @return true on success.
     */
    function renounceManagement(address src20)
        external
        onlyOwner
        returns (bool)
    {
        require(_registry[src20].owner != address(0), "SRC20 token contract not registered");

        require(ISRC20Roles(_registry[src20].roles).renounceManagement());

        return true;
    }

    /**
     * @dev Allows manager to transfer management to another address.
     *
     * @param src20 SRC20 token address.
     * @param newManager New manager address.
     * @return true on success.
     */
    function transferManagement(address src20, address newManager)
        public
        onlyOwner
        returns (bool)
    {
        require(_registry[src20].owner != address(0), "SRC20 token contract not registered");
        require(newManager != address(0), "newManager address is zero");

        require(ISRC20Roles(_registry[src20].roles).transferManagement(newManager));

        return true;
    }

    /**
     * @dev External function allowing consumers to check corresponding SRC20 amount
     * to supplied SWM amount.
     *
     * @param src20 SRC20 token to check for.this
     * @param swmValue SWM value.
     * @return Amount of SRC20 tokens.
     */
    function calcTokens(address src20, uint256 swmValue) external view returns (uint256) {
        return _calcTokens(src20, swmValue);
    }

    /**
     * @dev External view function for calculating SWM tokens needed for increasing/decreasing
     * src20 token supply.
     *
     * @param src20 Address of src20 contract
     * @param srcValue Amount of src20 tokens.this
     * @return Amount of SWM tokens
     */
    function swmNeeded(address src20, uint256 srcValue) external view returns (uint256) {
        return _swmNeeded(src20, srcValue);
    }

    /**
     * @dev External function for calculating how much SWM tokens are needed to be staked
     * in order to get 1 SRC20 token
     *
     * @param src20 Address of src20 token contract
     * @return Amount of SWM tokens
     */
    function getSrc20toSwmRatio(address src20) external returns (uint256) {
        uint256 totalSupply = ISRC20(src20).totalSupply();
        return totalSupply.mul(10 ** 18).div(_registry[src20].stake);
    }

    /**
     * @dev External view function to get current SWM stake
     *
     * @param src20 Address of SRC20 token contract
     * @return Current stake in wei SWM tokens
     */
    function getStake(address src20) external view returns (uint256) {
        return _registry[src20].stake;
    }

    /**
     * @dev Get address of token owner
     *
     * @param src20 Address of SRC20 token contract
     * @return Address of token owner
     */
    function getTokenOwner(address src20) external view returns (address) {
        return _registry[src20].owner;
    }

    /**
     * @dev Internal function calculating new SRC20 values based on minted ones. On every
     * new minting of supply new SWM and SRC20 values are saved for further calculations.
     *
     * @param src20 SRC20 token address.
     * @param swmValue SWM stake value.
     * @return Amount of SRC20 tokens.
     */
    function _calcTokens(address src20, uint256 swmValue) internal view returns (uint256) {
        require(src20 != address(0), "Token address is zero");
        require(swmValue != 0, "SWM value is zero");
        require(_registry[src20].owner != address(0), "SRC20 token contract not registered");

        uint256 totalSupply = ISRC20(src20).totalSupply();

        return swmValue.mul(totalSupply).div(_registry[src20].stake);
    }

    function _swmNeeded(address src20, uint256 srcValue) internal view returns (uint256) {
        uint256 totalSupply = ISRC20(src20).totalSupply();

        return srcValue.mul(_registry[src20].stake).div(totalSupply);
    }

    /**
     * @return true if `msg.sender` is the token owner of the registered SRC20 contract.
     */
    function _isTokenOwner(address src20) internal view returns (bool) {
        return msg.sender == _registry[src20].owner;
    }
}

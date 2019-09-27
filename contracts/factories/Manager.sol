pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../token/ISRC20Managed.sol";


/**
 * @dev Manager handles SRC20 burn/mint in relation to
 * SWM token staking.
 */
contract Manager is Ownable {
    using SafeMath for uint256;

    event SRC20SupplyMinted(address src20, address swmAccount, uint256 swmValue, uint256 src20Value);
    event SRC20StakeIncreased(address src20, address swmAccount, uint256 swmValue);
    event SRC20StakeDecreased(address src20, address swmAccount, uint256 swmValue);

    mapping (address => SRC20) internal _registry;

    struct SRC20 {
        address owner; // @TODO remove from struct, wherever used it is available as function parameter
        uint256 stake;
        uint256 _swm;
        uint256 _src;
        address minter;
    }

    IERC20 private _swmERC20;

    constructor(address swmERC20) public {
        require(swmERC20 != address(0), 'SWM ERC20 is zero address');

        _swmERC20 = IERC20(swmERC20);
    }

    modifier onlyTokenOwner(address src20) {
        require(_isTokenOwner(src20), "caller not token owner");
        _;
    }

    // Note that, like with token owner, there is only one manager per src20 token contract. 
    // It's not a role that a number of addresses can have. Only one.
    modifier onlyMinter(address src20) {
        require(msg.sender == _registry[src20].minter, "caller not token minter");
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
        _registry[src20]._swm = swmValue;
        _registry[src20]._src = src20Value;

        require(_swmERC20.transferFrom(swmAccount, address(this), swmValue));
        require(ISRC20Managed(src20).mint(_registry[src20].owner, src20Value));

        emit SRC20SupplyMinted(src20, swmAccount, swmValue, src20Value);

        return true;
    }

    /**
     * @dev Increase stake and mint SRC20 tokens based on current SWM/SRC20 ratio.
     * Only SRC20 Token owner can invoke this method.
     * Emits SRC20StakeIncreased event.
     *
     * @param src20 SRC20 token address.
     * @param swmAccount SWM ERC20 account holding enough SWM stake tokens (>= swmValue)
     * with manager contract address approved to transferFrom.
     * @param swmValue SWM stake value.
     * @return true on success.
     */
    function incStake(address src20, address swmAccount, uint256 swmValue)
        external
        onlyTokenOwner(src20)
        returns (bool)
    {
        require(swmAccount != address(0), "SWM account is zero");
        require(swmValue != 0, "SWM value is zero");
        require(_registry[src20].owner != address(0), "SRC20 token contract not registered");
        require(_registry[src20]._swm != 0, "Token not minted");

        _registry[src20].stake = _registry[src20].stake.add(swmValue);

        require(_swmERC20.transferFrom(swmAccount, address(this), swmValue));
        require(ISRC20Managed(src20).mint(_registry[src20].owner, _calcTokens(src20, swmValue)));

        emit SRC20StakeIncreased(src20, swmAccount, swmValue);

        return true;
    }

    /**
     * @dev Decrease stake and burn SRC20 tokens based on current SWM/SRC20 ratio.
     * Owner address in SRC20 Token needs to have required amount of SRC20 tokens
     * to burn.
     * Only SRC20 Token owner can invoke this method.
     * Emits SRC20StakeDecreased event.
     *
     * @param src20 SRC20 token address.
     * @param swmAccount SWM ERC20 account to receive SWM tokens.
     * @param swmValue SWM stake value.
     * @return true on success
     */
    function decStake(address src20, address swmAccount, uint256 swmValue)
        external
        onlyTokenOwner(src20)
        returns (bool)
    {
        require(swmAccount != address(0), "SWM account is zero");
        require(swmValue != 0, "SWM value is zero");
        require(_registry[src20].owner != address(0), "SRC20 token contract not registered");
        require(_registry[src20]._swm != 0, "Token not minted");

        _registry[src20].stake = _registry[src20].stake.sub(swmValue);

        require(_swmERC20.transfer(swmAccount, swmValue));
        require(ISRC20Managed(src20).burn(_registry[src20].owner, _calcTokens(src20, swmValue)));

        emit SRC20StakeDecreased(src20, swmAccount, swmValue);

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
        onlyManager(src20)
        returns (bool)
    {
        require(_registry[src20].owner != address(0), "SRC20 token contract not registered");

        require(ISRC20Managed(src20).renounceManagement());

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

        require(ISRC20Managed(src20).transferManagement(newManager));

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
        require(_registry[src20]._swm != 0, "Token not minted");

        return swmValue.mul(_registry[src20]._src).div(_registry[src20]._swm);
    }

    /**
     * @return true if `msg.sender` is the token owner of the registered SRC20 contract.
     */
    function _isTokenOwner(address src20) internal view returns (bool) {
        return msg.sender == _registry[src20].owner;
    }
}

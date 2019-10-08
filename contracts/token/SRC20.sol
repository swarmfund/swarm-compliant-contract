pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./SRC20Detailed.sol";
import "../interfaces/ISRC20.sol";
import "../interfaces/ISRC20Managed.sol";
import "../interfaces/ITransferRules.sol";
import "../interfaces/IFeatured.sol";
import "../interfaces/ISRC20Roles.sol";
import "../interfaces/ISRC20.sol";
import "../interfaces/ITransferRestrictions.sol";
import "../interfaces/IAssetRegistry.sol";


/**
 * @title SRC20 contract
 * @dev Base SRC20 contract.
 */
contract SRC20 is ISRC20, ISRC20Managed, SRC20Detailed, Ownable {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    mapping(address => uint256) public _balances;
    mapping(address => mapping(address => uint256)) public _allowances;
    uint256 public _totalSupply;
    uint256 public _maxTotalSupply;

    mapping(address => uint256) private _nonce;

    ISRC20Roles public _roles;
    IFeatured public _features;

    IAssetRegistry public _assetRegistry;

    /**
     * @description Configured contract implementing token restriction(s).
     * If set, transferToken will consult this contract should transfer
     * be allowed after successful authorization signature check.
     */
    ITransferRestrictions public _restrictions;

    /**
     * @description Configured contract implementing token rule(s).
     * If set, transfer will consult this contract should transfer
     * be allowed after successful authorization signature check.
     * And call doTransfer() in order for rules to decide where fund
     * should end up.
     */
    ITransferRules public _rules;

    modifier onlyAuthority() {
        require(_roles.isAuthority(msg.sender), "Caller not authority");
        _;
    }

    modifier onlyDelegate() {
        require(_roles.isDelegate(msg.sender), "Caller not delegate");
        _;
    }

    modifier onlyManager() {
        require(_roles.isManager(msg.sender), "Caller not manager");
        _;
    }

    modifier enabled(uint8 feature) {
        require(_features.isEnabled(feature), "Token feature is not enabled");
        _;
    }

    // Constructors
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 maxTotalSupply,
        address[] memory addressList
                    //  addressList[0] tokenOwner,
                    //  addressList[1] restrictions,
                    //  addressList[2] rules,
                    //  addressList[3] roles,
                    //  addressList[4] featured,
                    //  addressList[5] assetRegistry
    )
    SRC20Detailed(name, symbol, decimals)
    public
    {
        _assetRegistry = IAssetRegistry(addressList[5]);
        _transferOwnership(addressList[0]);

        _maxTotalSupply = maxTotalSupply;
        _updateRestrictionsAndRules(addressList[1], addressList[2]);

        _roles = ISRC20Roles(addressList[3]);
        _features = IFeatured(addressList[4]);
    }

    /**
     * @dev This method is intended to be executed by TransferRules contract when doTransfer is called in transfer
     * and transferFrom methods to check where funds should go.
     *
     * @param from The address to transfer from.
     * @param to The address to send tokens to.
     * @param value The amount of tokens to send.
     */
    function executeTransfer(address from, address to, uint256 value) external onlyAuthority returns (bool) {
        _transfer(from, to, value);
        return true;
    }

    /**
     * Update the rules and restrictions settings for transfers.
     * Only a Delegate can call this role
     * 
     * @param restrictions address implementing on-chain restriction checks
     * or address(0) if no rules should be checked on chain.
     * @param rules address implementing on-chain restriction checks
     * @return True on success.
     */
    function updateRestrictionsAndRules(address restrictions, address rules) external onlyDelegate returns (bool) {
        return _updateRestrictionsAndRules(restrictions, rules);
    }

    /**
     * @dev Internal function to update the restrictions and rules contracts.
     * Emits RestrictionsAndRulesUpdated event.
     *
     * @param restrictions address implementing on-chain restriction checks
     *                     or address(0) if no rules should be checked on chain.
     * @param rules address implementing on-chain restriction checks
     * @return True on success.
     */
    function _updateRestrictionsAndRules(address restrictions, address rules) internal returns (bool) {

        _restrictions = ITransferRestrictions(restrictions);
        _rules = ITransferRules(rules);

        if (rules != address(0)) {
            require(_rules.setSRC(address(this)), "SRC20 contract already set in transfer rules");
        }

        emit RestrictionsAndRulesUpdated(restrictions, rules);
        return true;
    }

    /**
     * @dev Transfer token to specified address. Caller needs to provide authorization
     * signature obtained from MAP API, signed by authority accepted by token issuer.
     * Emits Transfer event.
     *
     * @param to The address to send tokens to.
     * @param value The amount of tokens to send.
     * @param nonce Token transfer nonce, can not repeat nonce for subsequent
     * token transfers.
     * @param expirationTime Timestamp until transfer request is valid.
     * @param hash Hash of transfer params (kyaHash, from, to, value, nonce, expirationTime).
     * @param signature Ethereum ECDSA signature of msgHash signed by one of authorities.
     * @return True on success.
     */
    function transferToken(
        address to,
        uint256 value,
        uint256 nonce,
        uint256 expirationTime,
        bytes32 hash,
        bytes calldata signature
    )
        external returns (bool)
    {
        return _transferToken(msg.sender, to, value, nonce, expirationTime, hash, signature);
    }

    /**
     * @dev Transfer token to specified address. Caller needs to provide authorization
     * signature obtained from MAP API, signed by authority accepted by token issuer.
     * Whole allowance needs to be transferred.
     * Emits Transfer event.
     * Emits Approval event.
     *
     * @param from The address to transfer from.
     * @param to The address to send tokens to.
     * @param value The amount of tokens to send.
     * @param nonce Token transfer nonce, can not repeat nance for subsequent
     * token transfers.
     * @param expirationTime Timestamp until transfer request is valid.
     * @param hash Hash of transfer params (kyaHash, from, to, value, nonce, expirationTime).
     * @param signature Ethereum ECDSA signature of msgHash signed by one of authorities.
     * @return True on success.
     */
    function transferTokenFrom(
        address from,
        address to,
        uint256 value,
        uint256 nonce,
        uint256 expirationTime,
        bytes32 hash,
        bytes calldata signature
    )
        external returns (bool)
    {
        _transferToken(from, to, value, nonce, expirationTime, hash, signature);
        _approve(from, msg.sender, _allowances[from][msg.sender].sub(value));
        return true;
    }

    /**
    * @dev Transfer tokens from one address to another, used by token issuer. This
    * call requires only that from address has enough tokens, all other checks are
    * skipped.
    * Emits Transfer event.
    * Allowed only to token owners. Require 'ForceTransfer' feature enabled.
    *
    * @param from The address which you want to send tokens from.
    * @param to The address to send tokens to.
    * @param value The amount of tokens to send.
    * @return True on success.
    */
    function transferTokenForced(address from, address to, uint256 value)
        external
        enabled(_features.ForceTransfer())
        onlyOwner
        returns (bool)
    {
        _transfer(from, to, value);
        return true;
    }

    // Nonce management
    /**
     * @dev Returns next nonce expected by transfer functions that require it.
     * After any successful transfer, nonce will be incremented.
     *
     * @return Nonce for next transfer function.
     */
    function getTransferNonce() external view returns (uint256) {
        return _nonce[msg.sender];
    }

    /**
     * @dev Returns nonce for account.
     *
     * @return Nonce for next transfer function.
     */
    function getTransferNonce(address account) external view returns (uint256) {
        return _nonce[account];
    }

    // Account token burning management
    /**
     * @dev Function that burns an amount of the token of a given
     * account.
     * Emits Transfer event, with to address set to zero.
     *
     * @return True on success.
     */
    function burnAccount(address account, uint256 value)
        external
        enabled(_features.AccountBurning())
        onlyOwner
        returns (bool)
    {
        _burn(account, value);
        return true;
    }

    // Token managed burning/minting
    /**
     * @dev Function that burns an amount of the token of a given
     * account.
     * Emits Transfer event, with to address set to zero.
     * Allowed only to manager.
     *
     * @return True on success.
     */
    function burn(address account, uint256 value) external onlyManager returns (bool) {
        _burn(account, value);
        return true;
    }

    /**
     * @dev Function that mints an amount of the token to a given
     * account.
     * Emits Transfer event, with from address set to zero.
     * Allowed only to manager.
     *
     * @return True on success.
     */
    function mint(address account, uint256 value) external onlyManager returns (bool) {
        _mint(account, value);
        return true;
    }

    // ERC20 part-like interface methods
    /**
     * @dev Total number of tokens in existence.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return A uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * NOTE: Clients SHOULD make sure to create user interfaces in such a way that
     * they set the allowance first to 0 before setting it to another value for
     * the same spender. THOUGH The contract itself shouldn’t enforce it, to allow
     * backwards compatibility with contracts deployed before
     * Emit Approval event.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(_features.checkTransfer(msg.sender, to));

        if (_rules != ITransferRules(0)) {
            require(_rules.doTransfer(msg.sender, to, value), "Transfer failed");
        } else {
            _transfer(msg.sender, to, value);
        }

        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(_features.checkTransfer(from, to));

        if (_rules != ITransferRules(0)) {
            _approve(from, msg.sender, _allowances[from][msg.sender].sub(value));
            require(_rules.doTransfer(from, to, value), "Transfer failed");
        } else {
            _approve(from, msg.sender, _allowances[from][msg.sender].sub(value));
            _transfer(from, to, value);
        }

        return true;
    }

    /**
     * @dev Atomically increase approved tokens to the spender on behalf of msg.sender.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens that allowance will be increase for.
     */
    function increaseAllowance(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(value));
        return true;
    }

    /**
     * @dev Atomically decrease approved tokens to the spender on behalf of msg.sender.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens that allowance will be reduced for.
     */
    function decreaseAllowance(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(value));
        return true;
    }

    // Privates
    /**
     * @dev Internal transfer token to specified address. Caller needs to provide authorization
     * signature obtained from MAP API, signed by authority accepted by token issuer.
     * Emits Transfer event.
     *
     * @param from The address to transfer from.
     * @param to The address to send tokens to.
     * @param value The amount of tokens to send.
     * @param nonce Token transfer nonce, can not repeat nance for subsequent
     * token transfers.
     * @param expirationTime Timestamp until transfer request is valid.
     * @param hash Hash of transfer params (kyaHash, from, to, value, nonce, expirationTime).
     * @param signature Ethereum ECDSA signature of msgHash signed by one of authorities.
     * @return True on success.
     */
    function _transferToken(
        address from,
        address to,
        uint256 value,
        uint256 nonce,
        uint256 expirationTime,
        bytes32 hash,
        bytes memory signature
    )
        internal returns (bool)
    {
        if (address(_restrictions) != address(0)) {
            require(_restrictions.authorize(from, to, value), "transferToken restrictions failed");
        }

        require(now <= expirationTime, "transferToken params expired");
        require(nonce == _nonce[from], "transferToken params wrong nonce");

        (bytes32 kyaHash, string memory kyaUrl) = _assetRegistry.getKYA(address(this));

        require(
            keccak256(abi.encodePacked(kyaHash, from, to, value, nonce, expirationTime)) == hash,
            "transferToken params bad hash"
        );
        require(_roles.isAuthority(hash.toEthSignedMessageHash().recover(signature)), "transferToken params not authority");

        require(_features.checkTransfer(from, to));
        _transfer(from, to, value);

        return true;
    }

    /**
     * @dev Transfer token for a specified addresses.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);

        _nonce[from]++;

        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * Emit Transfer event.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), 'burning from zero address');

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);

        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Internal function that mints an amount of the token on given
     * account.
     * Emit Transfer event.
     *
     * @param account The account where tokens will be minted.
     * @param value The amount that will be minted.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0), 'minting to zero address');

        _totalSupply = _totalSupply.add(value);
        require(_totalSupply <= _maxTotalSupply || _maxTotalSupply == 0, 'trying to mint too many tokens!');

        _balances[account] = _balances[account].add(value);

        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Approve an address to spend another addresses' tokens.
     * NOTE: Clients SHOULD make sure to create user interfaces in such a way that
     * they set the allowance first to 0 before setting it to another value for
     * the same spender. THOUGH The contract itself shouldn’t enforce it, to allow
     * backwards compatibility with contracts deployed before
     * Emit Approval event.
     *
     * @param owner The address that owns the tokens.
     * @param spender The address that will spend the tokens.
     * @param value The number of tokens that can be spent.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), 'approve from the zero address');
        require(spender != address(0), 'approve to the zero address');

        _allowances[owner][spender] = value;

        emit Approval(owner, spender, value);
    }

    /**
     * Perform multiple token transfers from the token owner's address.
     * The tokens should already be minted. If this function is to be called by
     * an actor other than the owner (a delegate), the owner has to call approve()
     * first to set up the delegate's allowance.
     *
     * @param _addresses an array of addresses to transfer to
     * @param _values an array of values
     * @return True on success
     */
    function bulkTransfer (
        address[] calldata _addresses, uint256[] calldata _values) external onlyDelegate returns (bool) {
        require(_addresses.length == _values.length, "Input dataset length mismatch");

        uint256 count = _addresses.length;
        for (uint256 i = 0; i < count; i++) {
            address to = _addresses[i];
            uint256 value = _values[i];
            _approve(owner(), msg.sender, _allowances[owner()][msg.sender].sub(value));
            _transfer(owner(), to, value);
        }

        return true;
    }

    /**
     * Perform multiple token transfers from the token owner's address.
     * The tokens should already be minted. If this function is to be called by
     * an actor other than the owner (a delegate), the owner has to call approve()
     * first to set up the delegate's allowance.
     *
     * Data needs to be packed correctly before calling this function.
     *
     * @param _lotSize number of tokens in the lot
     * @param _transfers an array or encoded transfers to perform
     * @return True on success
     */
    function encodedBulkTransfer (
        uint160 _lotSize, uint256[] calldata _transfers) external onlyDelegate returns (bool) {

        uint256 count = _transfers.length;
        for (uint256 i = 0; i < count; i++) {
            uint256 tr = _transfers[i];
            uint256 value = (tr >> 160) * _lotSize;
            address to = address (tr & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
            _approve(owner(), msg.sender, _allowances[owner()][msg.sender].sub(value));
            _transfer(owner(), to, value);
        }

        return true;
    }
}

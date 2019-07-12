pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./SRC20Detailed.sol";
import "./ISRC20.sol";
import "./ISRC20Owned.sol";
import "./ISRC20Managed.sol";
import "./Featured.sol";
import "./AuthorityRole.sol";
import "./Freezable.sol";
import "./DelegateRole.sol";
import "../rules/ITransferRestriction.sol";
import "./Managed.sol";


/**
 * @title SRC20 contract
 * @dev Base SRC20 contract.
 */
contract SRC20 is ISRC20, ISRC20Owned, ISRC20Managed, SRC20Detailed, Featured,
        AuthorityRole, DelegateRole, Freezable, Ownable, Managed {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    mapping(address => uint256) private _nonce;

    struct KYA {
        bytes32 kyaHash;
        string kyaUrl;
    }

    KYA private _kya;

    /**
     * @description Configured contract implementing token restriction(s).
     * If set, transferToken will consult this contract should transfer
     * be allowed after successful authorization signature check.
     */
    ITransferRestriction private _restrictions;


    // Constructors
    constructor(
        address owner,
        string memory name,
        string memory symbol,
        uint8 decimals,
        bytes32 kyaHash,
        string memory kyaUrl,
        address restrictions,
        uint8 features,
        uint256 totalSupply
    )
    SRC20Detailed(name, symbol, decimals)
    Featured(features)
    public
    {
        _transferOwnership(owner);

        _totalSupply = totalSupply;
        _balances[owner] = _totalSupply;
        _updateKYA(kyaHash, kyaUrl, restrictions);
    }

    // KYA management
    /**
     * @dev Update KYA document, sending document hash and url. Hash is
     * SHA256 hash of document content.
     * Emits KYAUpdated event.
     * Allowed to be called by owner or delete accounts.
     *
     * @param kyaHash SHA256 hash of KYA document.
     * @param kyaUrl URL of token's KYA document (ipfs, http, etc.).
     * @param restrictions address implementing on-chain restriction checks
     * or address(0) if no rules should be checked on chain.
     * @return True on success.
     */
    function updateKYA(bytes32 kyaHash, string calldata kyaUrl, address restrictions) external onlyOwnerOrDelegate returns (bool) {
        return _updateKYA(kyaHash, kyaUrl, restrictions);
    }

    /**
     * @dev Retrieve token's KYA document's hash and url.
     *
     * @return Hash of KYA document.
     * @return URL of KYA document.
     */
    function getKYA() external view returns (bytes32, string memory, address) {
        return (_kya.kyaHash, _kya.kyaUrl, address(_restrictions));
    }

    /**
     * @dev Internal function to change KYA hash and url.
     * Emits KYAUpdated event.
     *
     * @param kyaHash SHA256 hash of KYA document.
     * @param kyaUrl URL of token's KYA document (ipfs, http, etc.).
     * @param restrictions address implementing on-chain restriction checks
     * or address(0) if no rules should be checked on chain.
     * @return True on success.
     */
    function _updateKYA(bytes32 kyaHash, string memory kyaUrl, address restrictions) internal returns (bool) {
        _kya.kyaHash = kyaHash;
        _kya.kyaUrl = kyaUrl;
        _restrictions = ITransferRestriction(restrictions);

        emit KYAUpdated(kyaHash, kyaUrl, restrictions);

        return true;
    }

    /**
     * @dev Transfer token to specified address. Caller needs to provide authorization
     * signature obtained from MAP API, signed by authority accepted by token issuer.
     * Emits Transfer event. 
     *
     * @param to The address to send tokens to.
     * @param value The amount of tokens to send.
     * @param nonce Token transfer nonce, can not repeat nance for subsequent
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
        enabled(Featured.ForceTransfer)
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


    // Authority management
    /**
     * @dev Check if specified account is authority. Authorities are accounts
     * that can sign token transfer request, usually after off-chain token restriction
     * checks.
     * 
     * @return True if specified account is authority account.
     */
    function isAuthority(address account) external view returns (bool) {
        return _hasAuthority(account);
    }

    /**
     * @dev Add account to token authorities list.
     * Emits AuthorityAdded event.
     */
    function addAuthority(address account) external onlyOwner {
        _addAuthority(account);
    }

    /**
     * @dev Removes account from token authorities list.
     * Emits AuthorityRemoved event.
     */
    function removeAuthority(address account) external onlyOwner {
        _removeAuthority(account);
    }

    // Delegate management
    /**
     * @dev Check if specified account is delegate. Delegate is accounts
     * allowed to do certain operations on contract, apart from owner.
     *
     * @return True if specified account is delegate account.
     */
    function isDelegate(address account) external view returns (bool) {
        return _hasDelegate(account);
    }

    /**
     * @dev Add account to token delegates list.
     * Emits DelegateAdded event.
     */
    function addDelegate(address account) external onlyOwner {
        _addDelegate(account);
    }

    /**
     * @dev Removes account from token delegates list.
     * Emits DelegateRemoved event.
     */
    function removeDelegate(address account) external onlyOwner {
        _removeDelegate(account);
    }

    /**
     * @dev Throws if caller by other than owner or delegate.
     */
    modifier onlyOwnerOrDelegate() {
        require(isOwner() || _hasDelegate(msg.sender), "Not Owner or Delegate");
        _;
    }

    // Account and token freezing management
    /**
     * @dev Check if specified account is frozen. Token issuer can
     * freeze any account at any time and stop accounts making
     * transfers.
     *
     * @return True if account is frozen.
     */
    function isFrozen(address account) external view returns (bool) {
        return _isFrozen(account);
    }

    /**
     * @dev Freezes account.
     * Emits AccountFrozen event.
     */
    function freezeAccount(address account)
        external
        enabled(Featured.Freezing)
        onlyOwner
    {
        _freezeAccount(account);
    }

    /**
     * @dev Unfreezes account.
     * Emits AccountUnfrozen event.
     */
    function unfreezeAccount(address account)
        external
        enabled(Featured.Freezing)
        onlyOwner
    {
        _unfreezeAccount(account);
    }

    /**
     * @dev Check if token is frozen. Token issuer can freeze token
     * at any time and stop all accounts from making transfers. When
     * token is frozen, isFrozen(account) returns true for every
     * account.
     *
     * @return True if token is frozen.
     */
    function isTokenFrozen() external view returns (bool) {
        return _isTokenFrozen();
    }

    /**
     * @dev Freezes token.
     * Emits TokenFrozen event.
     */
    function freezeToken()
        external
        enabled(Featured.Freezing)
        onlyOwner
    {
        _freezeToken();
    }

    /**
     * @dev Freezes token.
     * Emits TokenUnfrozen event.
     */
    function unfreezeToken()
        external
        enabled(Featured.Freezing)
        onlyOwner
    {
        _unfreezeToken();
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
        enabled(Featured.AccountBurning)
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
        require(_isFrozen(from) == false && _isFrozen(to) == false, "transferToken frozen");
        require(now <= expirationTime, "transferToken params expired");
        require(nonce == _nonce[from], "transferToken params wrong nonce");
        require(
            keccak256(abi.encodePacked(_kya.kyaHash, from, to, value, nonce, expirationTime)) == hash,
            "transferToken params bad hash"
        );
        require(_hasAuthority(hash.toEthSignedMessageHash().recover(signature)), "transferToken params not authority");

        if (_restrictions != ITransferRestriction(0)) {
            require(_restrictions.authorize(address(this), from, to, value), "transferToken restrictions failed");
        }

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

        _nonce[from]++; // no need for safe math here

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
}

pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IIssuerStakeOfferPool.sol";
import "../interfaces/IGetRateMinter.sol";
import "../interfaces/IUniswap.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraise {

    using SafeMath for uint256;

    event Contribution(address indexed from, uint256 amount, uint256 sequence, address baseCurrency);

    // Setup variables that never change
    string public label;
    address public src20;
    uint256 public tokenAmount;
    uint256 public startDate;
    uint256 public endDate;
    uint256 public softCap;
    uint256 public hardCap;
    address public baseCurrency;

    bool public contributionLocking = true;

    uint256 public tokenPriceBCY;
    uint256 public totalTokenAmount;

    address zeroAddr = 0x0000000000000000000000000000000000000000; // Stands for ETH
    address erc20DAI;
    address erc20USDC;
    address erc20WBTC;
    address SwarmERC20;
    address minter;

    address payable issuerWallet;

    // State variables that change over time
    struct contribution {
        address currency;
        uint amount;
        uint sequence;
    }

    mapping(address => contribution[]) contributionsList;

    uint256 sequence;

    bool isOngoing = true;

    uint256 acceptedAmountETH;
    uint256 acceptedAmountDAI;
    uint256 acceptedAmountUSDC;
    uint256 acceptedAmountWBTC;

    constructor(
        string memory _label,
        address _src20,
        uint256 _tokenAmount,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _softCap,
        uint256 _hardCap,
        address _baseCurrency
    ) public {
        label = _label;
        src20 = _src20;
        tokenAmount = _tokenAmount;
        startDate = _startDate;
        endDate = _endDate;
        softCap = _softCap;
        hardCap = _hardCap;
        
        require(_baseCurrency == erc20DAI  ||
                _baseCurrency == erc20USDC ||
                _baseCurrency == erc20WBTC ||
                _baseCurrency == zeroAddr, 'Unsupported base currency');

        baseCurrency = _baseCurrency;
    }

    function() external payable {
        require(isOngoing, 'Fundraise is not oingoing anymore!');

        sequence++;

        contribution memory c;
        c.currency = address(0);
        c.amount = msg.value;
        c.sequence = sequence;

        contributionsList[msg.sender].push(c);
        emit Contribution(msg.sender, msg.value, sequence, address(0));
    }

    function setTokenPriceBCY(uint256 _tokenPriceBCY) external returns (bool) {
        // One has to be set or the other, never both.
        tokenPriceBCY = _tokenPriceBCY;
        totalTokenAmount = 0;
        return true;
    }

    function setTotalTokenAmount(uint256 _totalTokenAmount) external returns (bool) {
        // One has to be set or the other, never both.
        totalTokenAmount = _totalTokenAmount;
        tokenPriceBCY = 0;
        return true;
    }

    function contribute(address erc20, uint256 amount) public returns (bool) {
        require(isOngoing, 'Fundraise is not oingoing anymore!');
        require(IERC20(erc20).transferFrom(msg.sender, address(this), amount), 'ERC20 transfer failed!');

        sequence++;

        contribution memory c;
        c.currency = erc20;
        c.amount = amount;
        c.sequence = sequence;

        contributionsList[msg.sender].push(c);

        return true;
    }

    function acceptContribution(address contributor, address erc20, uint256 amount) external returns (bool) {
        return true;
    }

    function rejectContribution(address contributor, address erc20, uint256 amount) external returns (bool) {
        return true;
    }

    function withdrawContributionETH() external returns (bool) {
        require(!isOngoing, 'Cannot withdraw, fundraise is ongoing');

        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            if (contributionsList[msg.sender][i].currency != address(0))
                continue;
            msg.sender.transfer(contributionsList[msg.sender][i].amount);
            contributionsList[msg.sender][i].amount = 0;
        }

        return true;
    }

    function withdrawContributionToken() external returns (bool) {
        require(!isOngoing, 'Cannot withdraw, fundraise is ongoing');

        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            if (contributionsList[msg.sender][i].currency == address(0))
                continue;
            // Transfer from
            require(IERC20(contributionsList[msg.sender][i].currency).transferFrom(
                    address(this),
                    msg.sender,
                    contributionsList[msg.sender][i].amount),
                'ERC20 transfer failed!');
            contributionsList[msg.sender][i].amount = 0;
        }

        return true;
    }

    function allowContributionWithdrawals() external returns (bool) {
        contributionLocking = false;
        return true;
    }

    function setPresale(uint256 amountBCY, uint256 tokens) external returns (bool) {
        return true;
    }

    function getPresale() external returns (uint256, uint256) {
        return (0, 0);
    }

    function finishFundraising() external returns (bool) {
        isOngoing = false;
        return true;
    }

    function setContributionRules(address rules) external returns (bool) {
        return true;
    }

    function setContributorRestrictions(address restrictions) external returns (bool) {
        return true;
    }

    function getHistoricalBalanceETH(uint256 _sequence) external returns (uint256) {
        return uint256(0);
    }

    function isContributionAccepted(uint256 _sequence) external returns (bool) {
        return true;
    }

    function stakeAndMint(address ISOP) external returns (bool) {
        address[] memory a;
        stakeAndMint(ISOP, a);
    }

    function stakeAndMint(address ISOP, address[] memory addressList) public returns (bool) {

        // Update the NAV
        // assetRegistry.updateNetAssetValueUSD(src20, netAssetValueUSD);
        uint256 netAssetValueUSD = softCap;
        uint256 swmAmount = IGetRateMinter(minter).calcStake(netAssetValueUSD);

        // Collect the SWM tokens from ISOP. For now we don't loop but only have
        // One provider, chosen by the Token Issuer
        address swmProvider = addressList[0];
        uint256 priceETH = IIssuerStakeOfferPool(ISOP).getSWMPriceETH(swmProvider, swmAmount);
        IIssuerStakeOfferPool(ISOP).buySWMTokens.value(priceETH)(swmProvider, swmAmount);

        // SWM are on the Fundraise contract, approve the minter to spend them
        IERC20(SwarmERC20).approve(minter, swmAmount);

        // Mint
        uint256 totalContributionsBCY = toBCY(acceptedAmountETH, zeroAddr) + 
                                        toBCY(acceptedAmountDAI, erc20DAI) +
                                        toBCY(acceptedAmountUSDC, erc20USDC) +
                                        toBCY(acceptedAmountWBTC, erc20WBTC);
        uint256 numSRC20Tokens = totalTokenAmount > 0 ? totalTokenAmount : totalContributionsBCY / tokenPriceBCY;        
        IGetRateMinter(minter).stakeAndMint(src20, numSRC20Tokens);

        // Withdraw
        // Withdraw accepted ETH
        issuerWallet.transfer(acceptedAmountETH);

        // Withdraw accepted DAI
        IERC20(erc20DAI).approve(issuerWallet, acceptedAmountDAI);
        IERC20(erc20DAI).transferFrom(address(this), issuerWallet, acceptedAmountDAI);

        // Withdraw accepted USDC
        IERC20(erc20USDC).approve(issuerWallet, acceptedAmountUSDC);
        IERC20(erc20USDC).transferFrom(address(this), issuerWallet, acceptedAmountUSDC);
        
        // Withdraw accepted WBTC
        IERC20(erc20WBTC).approve(issuerWallet, acceptedAmountWBTC);
        IERC20(erc20WBTC).transferFrom(address(this), issuerWallet, acceptedAmountWBTC);

        return true;

    }

    // Convert an amount in currency into an amount in base currency
    function toBCY(uint256 amount, address currency) public returns (uint256) {

        uint256 amountETH;
        uint256 amountBCY;

        // If same, just return the input
        if (currency == baseCurrency)
            return amount;

        // ERC20 - ETH
        if (baseCurrency == zeroAddr && currency != zeroAddr) {
            amountBCY = IUniswap(currency).getTokenToEthInputPrice(amount);
            return amountBCY;
        }

        // ETH - ERC20
        if (currency == zeroAddr) {
            amountBCY = IUniswap(baseCurrency).getEthToTokenInputPrice(amount);
            return amountBCY;
        }

        // ERC20 - ERC20
        amountETH = IUniswap(currency).getTokenToEthInputPrice(amount);
        amountBCY = IUniswap(baseCurrency).getEthToTokenInputPrice(amountETH);
        return amountBCY;

    }

}
pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IContributionRules.sol";
import "../interfaces/IContributorRestrictions.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraise {

    using SafeMath for uint256;

    string public label;
    address public src20;
    uint256 public tokenAmount;
    uint256 public startDate;
    uint256 public endDate;
    uint256 public softCap;
    uint256 public hardCap;
    address public baseCurrency;

    uint256 public expirationTime = 7776000; // 60 * 60 * 24 * 90 = ~3months

    bool public contributionLocking = true;

    uint256 public tokenPriceBCY;
    uint256 public totalTokenAmount;

    event Contribution(address indexed from, uint256 amount, uint256 indexed sequence, address baseCurrency);

    struct contribution {
        address currency;
        uint256 amount;
        uint256 sequence;
        bool accepted;
    }

    struct AcceptedContribution {
        uint256 amount;
    }

    mapping(address => contribution[]) contributionsList;
    // contributor => currency =? sum
    mapping(address => mapping(address => AcceptedContribution)) accContribution;

    uint256 public sequence;

    bool public isFinished;

    address public contributionRules;
    address public contributorRestrictions;

    modifier onlyContributorRestrictions() {
        require(msg.sender == contributorRestrictions);
        _;
    }

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
        baseCurrency = _baseCurrency;
    }

    function() external payable {
        require(tokenPriceBCY != 0 || totalTokenAmount != 0, "Contribution failed: token price or total token amount are not set");
        require(block.timestamp >= startDate, "Contribution failed: fundraising did not start");
        require(block.timestamp <= endDate, "Contribution failed: fundraising has ended");

        sequence++;

        contribution memory c;
        c.currency = address(0);
        c.amount = msg.value;
        c.sequence = sequence;

        contributionsList[msg.sender].push(c);

        _acceptContributor(msg.sender);

        emit Contribution(msg.sender, msg.value, sequence, address(0));
    }

    function setTokenPriceBCY(uint256 _tokenPriceBCY) external returns (bool) {
        // One has to be set or the other, never both.
        require(tokenPriceBCY == 0, "Token price already set");
        require(totalTokenAmount == 0, "Total token amount already set");

        tokenPriceBCY = _tokenPriceBCY;
        return true;
    }

    function setTotalTokenAmount(uint256 _totalTokenAmount) external returns (bool) {
        require(tokenPriceBCY == 0, "Token price already set");
        require(totalTokenAmount == 0, "Total token amount already set");

        totalTokenAmount = _totalTokenAmount;
        return true;
    }

    function contribute(address erc20, uint256 amount) public returns (bool) {
        require((tokenPriceBCY != 0 || totalTokenAmount != 0), "Contribution failed: token price or total token amount are not set");
        require(block.timestamp >= startDate, "Contribution failed: fundraising did not start");
        require(block.timestamp <= endDate, "Contribution failed: fundraising has ended");
        require(IERC20(erc20).transferFrom(msg.sender, address(this), amount), 'Contribution failed: ERC20 transfer failed!');

        sequence++;

        contribution memory c;
        c.currency = erc20;
        c.amount = amount;
        c.sequence = sequence;

        contributionsList[msg.sender].push(c);

        _acceptContributor(msg.sender);

        emit Contribution(msg.sender, amount, sequence, erc20);

        return true;
    }

    function withdrawContributionETH() external returns (bool) {
        require(isFinished == true && block.timestamp < endDate.add(expirationTime), 'Withdrawal failed: fundraise has not finished');

        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            if (contributionsList[msg.sender][i].currency != address(0))
                continue;
            msg.sender.transfer(contributionsList[msg.sender][i].amount);
        }

        delete contributionsList[msg.sender];

        return true;
    }

    function withdrawContributionToken() external returns (bool) {
        require(isFinished == true && block.timestamp < endDate.add(expirationTime), 'Withdrawal failed: fundraise has not finished');

        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            if (contributionsList[msg.sender][i].currency == address(0))
                continue;
            // Transfer from
            require(IERC20(contributionsList[msg.sender][i].currency).transferFrom(
                    address(this),
                    msg.sender,
                    contributionsList[msg.sender][i].amount),
                'ERC20 transfer failed!');
        }

        delete contributionsList[msg.sender];

        return true;
    }

    function allowContributionWithdrawals() external returns (bool) {
        delete contributionLocking;
        return true;
    }

    function setPresale(uint256 amountBCY, uint256 tokens) external returns (bool) {
        return true;
    }

    function getPresale() external returns (uint256, uint256) {
        return (0, 0);
    }

    function finishFundraising() external returns (bool) {
        require(isFinished == false, "Failed to finish fundraising: Fundraising already finished");
        require(block.timestamp < endDate.add(expirationTime), "Failed to finish fundraising: expiration time passed");

        isFinished = true;

        return true;
    }

    function setContributionRules(address rules) external returns (bool) {
        require(contributionRules != address(0), "Contribution rules already set");

        contributionRules = rules;
        return true;
    }

    function setContributorRestrictions(address restrictions) external returns (bool) {
        require(contributorRestrictions != address(0), "Contributor restrictions already set");

        contributorRestrictions = restrictions;
        return true;
    }

    function getHistoricalBalanceETH(uint256 _sequence) external returns (uint256) {
        return uint256(0);
    }

    function isContributionAccepted(uint256 _sequence) external returns (bool) {
        return true;
    }

    function acceptContributor(address contributor) external onlyContributorRestrictions returns (bool) {
        _acceptContributor(contributor);
        return true;
    }

    function rejectContributor(address contributor) external onlyContributorRestrictions returns (bool) {
        _rejectContributor(contributor);
        return true;
    }

    function _acceptContributor(address contributor) internal returns (bool) {
        require(IContributorRestrictions(contributorRestrictions).checkContributor(contributor));

        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            if (contributionsList[msg.sender][i].accepted) {
                continue;
            }

            contribution memory contr = contributionsList[msg.sender][i];

            accContribution[contributor][contr.currency].amount =
            accContribution[contributor][contr.currency].amount.add(
                contributionsList[msg.sender][i].amount);

            require(IContributionRules(contributionRules).checkContribution(accContribution[contributor][contr.currency].amount));// this is bad, rewrite
            // min/max amount
            // @TODO should return new truncated amount if over max amount or hardCap and exit

            contributionsList[msg.sender][i].accepted = true;
        }

        return true;
    }

    function _rejectContributor(address contributor) internal returns (bool) {
        require(!IContributorRestrictions(contributorRestrictions).checkContributor(contributor));

        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            if (!contributionsList[msg.sender][i].accepted) {
                continue;
            }

            contribution memory contr = contributionsList[msg.sender][i];

            accContribution[contributor][contr.currency].amount =
            accContribution[contributor][contr.currency].amount.sub(
                contributionsList[msg.sender][i].amount);

            // if amount becomes negative than means the investment was partial accepted (max amount or hard-cap

            delete contributionsList[msg.sender][i].accepted;
        }

        return true;
    }

    // @TODO expose function to claim tokens
}
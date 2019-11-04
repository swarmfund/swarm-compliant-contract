pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

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

    uint256 public tokenPriceBCY;
    uint256 public totalTokenAmount;

    struct contribution {
        address currency;
        uint amount;
        uint sequence;
    }

    mapping(address => contribution[]) contributionsList;

    uint256 sequence;

    bool isOngoing = true;

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

    function () external payable {
        require(isOngoing, 'Fundraise is not oingoing anymore!');
        sequence++;
        contribution memory c;
        c.currency = address(0);
        c.amount = msg.value;
        c.sequence = sequence;
        contributionsList[msg.sender].push(c);
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
        
        for(uint256 i=0; i<contributionsList[msg.sender].length; i++) {
            if(contributionsList[msg.sender][i].currency != address(0))
                continue;
            msg.sender.transfer(contributionsList[msg.sender][i].amount);
            contributionsList[msg.sender][i].amount = 0;
        }
        
        return true;
    }

    function withdrawContributionToken() external returns (bool) {
        require(!isOngoing, 'Cannot withdraw, fundraise is ongoing');

        for(uint256 i=0; i<contributionsList[msg.sender].length; i++) {
            if(contributionsList[msg.sender][i].currency == address(0))
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

    function finishFundraising() external returns (bool) {
        isOngoing = false;
        return true;
    }
}
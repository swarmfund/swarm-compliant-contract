const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const SwarmPoweredFundraiseMock = artifacts.require('SwarmPoweredFundraiseMock');
const Erc20Token = artifacts.require('SwarmTokenMock');
const PassContributionRules = artifacts.require('PassContributionRules');
const FailContributionRules = artifacts.require('FailContributionRules');

contract('SwarmPoweredFundraise', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor, src20]) {
    const label = "mvpworkshop.co";
    const tokenAmount = new BN(1000);
    const startDate = new BN(moment().unix());
    const endDate = new BN(moment().unix() + 100);
    const softCap = new BN(100);
    const hardCap = new BN(1000);
    let baseCurrency;

    const ercTotalSupply = new BN(10000);

    const tokenPrice = new BN(10);
    const totalTokenAmount = new BN(100000);

    const amount = new BN(10);
    const minAmount = new BN(5);
    const maxAmount = new BN(100);

    beforeEach(async function () {
        this.acceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
        this.notAcceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
        baseCurrency = this.acceptedToken.address;

        this.passContributionRules = PassContributionRules.new();
        this.failContributionRules = FailContributionRules.new();

        // @TODO should register erc20 tokens to some kind of accepted currency registry
    });

    describe('Handling if fundraising is set up correctly', function () {
        it('should have all needed variables', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            const fundLabel = await swarmPoweredFundraiseMock.label();
            const fundSrc20 = await swarmPoweredFundraiseMock.src20();
            const fundTokenAmount = await swarmPoweredFundraiseMock.tokenAmount();
            const fundStartDate = await swarmPoweredFundraiseMock.startDate();
            const fundEndDate = await swarmPoweredFundraiseMock.endDate();
            const fundSoftCap = await swarmPoweredFundraiseMock.softCap();
            const fundHardCap = await swarmPoweredFundraiseMock.hardCap();
            const fundBaseCurrency = await swarmPoweredFundraiseMock.baseCurrency();

            assert.equal(label === fundLabel, true);
            assert.equal(src20 === fundSrc20, true);
            assert.equal(fundTokenAmount.eq(tokenAmount), true);
            assert.equal(fundStartDate.eq(startDate), true);
            assert.equal(fundEndDate.eq(endDate), true);
            assert.equal(fundSoftCap.eq(softCap), true);
            assert.equal(fundHardCap.eq(hardCap), true);
            assert.equal(fundBaseCurrency === baseCurrency, true);
        });

        it('should fail if fundraising is started without src20 token', async function () {
            await shouldFail.reverting.withMessage(
                SwarmPoweredFundraiseMock.new(
                    label,
                    constants.ZERO_ADDRESS, // src20
                    tokenAmount,
                    startDate,
                    endDate,
                    softCap,
                    hardCap,
                    baseCurrency,
                    {from: issuer}),
                "Fundraising deployment failed: SRC20 token can not be zero address");
        });

        it('should allow token issuer to set src20 token price', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await swarmPoweredFundraiseMock.setTokenPriceBCY(tokenPrice, {from: issuer});
            const fundTokenPrice = await swarmPoweredFundraiseMock.tokenPriceBCY();
            assert.equal(fundTokenPrice.eq(tokenPrice), true);
        });

        it('should allow token issuer to set total amount of src20 tokens', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await swarmPoweredFundraiseMock.setTotalTokenAmount(totalTokenAmount, {from: issuer});
            const fundTotalTokenAmount = await swarmPoweredFundraiseMock.totalTokenAmount();
            assert.equal(fundTotalTokenAmount.eq(totalTokenAmount), true);
        });

        it('should not allow token issuer to set src20 token price if total amount of tokens are already set', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await swarmPoweredFundraiseMock.setTotalTokenAmount(totalTokenAmount, {from: issuer});

            await shouldFail.reverting.withMessage(
                swarmPoweredFundraiseMock.setTokenPriceBCY(tokenPrice, {from: issuer}),
                "Failed to set token price: total token amount already set");
        });

        it('should not allow token issuer to set total amount of src20 tokens if price is already set', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await swarmPoweredFundraiseMock.setTokenPriceBCY(tokenPrice, {from: issuer});

            await shouldFail.reverting.withMessage(
                swarmPoweredFundraiseMock.setTotalTokenAmount(totalTokenAmount, {from: issuer}),
                "Failed to set total token amount: token price already set");
        });

        it('should not be able to contribute if fundraising did not start', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                moment().unix() + 100,
                moment().unix() + 200,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await shouldFail.reverting.withMessage(swarmPoweredFundraiseMock.send(amount, {from: owner}),
                "Contribution failed: fundraising did not start");
        });

        // Locking contributions
        it('should be able to withdraw contribution if contributions withdrawal are allowed', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            const beforeBalance = await swarmPoweredFundraiseMock.getBalanceETH(owner);

            await swarmPoweredFundraiseMock.allowContributionWithdrawals({from: issuer});
            await swarmPoweredFundraiseMock.send(amount, {from: owner});
            await swarmPoweredFundraiseMock.withdrawContributionETH({from: owner});

            const afterBalance = await swarmPoweredFundraiseMock.getBalanceETH(owner);

            assert.equal(beforeBalance.eq(afterBalance), true);
        });

        it('should be able to put presale amount and presale tokens with specialized functions', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await swarmPoweredFundraiseMock.setPresale(amount, amount.div(tokenPrice));

            const {afterAmount, afterTokens} = await swarmPoweredFundraiseMock.getPresale();

            assert.equal(amount.eq(afterAmount), true);
            assert.equal(amount.div(tokenPrice).eq(afterTokens), true);
        });

        it('should fail if presale amount is larger than hardcap', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await shouldFail.reverting.withMessage(swarmPoweredFundraiseMock.setPresale(amount, amount.div(tokenPrice)),
                "Setting presale failed: amount is larger than hardcap");
        });

        it('should fail if presale tokens is larger than total amount of tokens', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                baseCurrency,
                {from: issuer});

            await shouldFail.reverting.withMessage(swarmPoweredFundraiseMock.setPresale(hardCap.add(1), hardCap.add(1).div(tokenPrice)),
                "Setting presale failed: tokens is larger than total token supply");
        });

        it('should be able to set base currency from accepted currencies', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                this.acceptedToken.address,
                {from: issuer});

            const baseCurrency = await swarmPoweredFundraiseMock.baseCurrency();

            assert.equal(this.acceptedToken.address, baseCurrency);
        });

        it('should not be able to set base currency from not accepted currencies', async function () {
            await shouldFail.reverting.withMessage(SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                this.notAcceptedToken.address,
                {from: issuer}),
                "Swarm powered fundraising failed to deploy: base currency not accepted")
        });

        it('should pass contribution rules', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                this.acceptedToken.address,
                {from: issuer});

            const beforeBalance = await swarmPoweredFundraiseMock.getBalanceETH(owner);

            await swarmPoweredFundraiseMock.setContributionRules(this.passContributionRules.address);

            await swarmPoweredFundraiseMock.send(amount, {from: owner});
            const afterBalance = await swarmPoweredFundraiseMock.getBalanceETH(owner);

            // check contribution
            assert.equal(beforeBalance.equal(afterBalance));
        });

        it('should fail contribution rules', async function () {
            const swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
                label,
                src20,
                tokenAmount,
                startDate,
                endDate,
                softCap,
                hardCap,
                this.acceptedToken.address,
                {from: issuer});

            await swarmPoweredFundraiseMock.setContributionRules(this.failContributionRules.address);

            await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseMock.send(amount, {from:owner}),
                "Contribution failed: contribution rules failed");
        });
    });
});

const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const SwarmPoweredFundraiseMock = artifacts.require('SwarmPoweredFundraiseMock');

const ContributorRestrictions = artifacts.require('ContributorRestrictions');

const SwarmPoweredFundraiseFinished = artifacts.require('SwarmPoweredFundraiseFinished');
const SwarmPoweredFundraiseCanceled = artifacts.require('SwarmPoweredFundraiseCanceled');
const SwarmPoweredFundraiseExpired = artifacts.require('SwarmPoweredFundraiseExpired');

const Erc20Token = artifacts.require('SwarmTokenMock');

contract('Issuer actions', async function ([_, whitelistManager, owner, issuer, contributor, src20]) {
    const label = "mvpworkshop.co";
    const tokenAmount = new BN(1000);
    const startDate = new BN(moment().unix());
    const endDate = new BN(moment().unix() + 100);
    const softCap = new BN(100);
    const hardCap = new BN(1000);

    const ercTotalSupply = new BN(10000);
    const amount = new BN(10);
    const minAmount = new BN(11);
    const maxAmount = new BN(100);

    beforeEach(async function () {
        this.acceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
        this.notAcceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});

        // @TODO accepted token registry

        this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
            label,
            src20,
            tokenAmount,
            startDate,
            endDate,
            softCap,
            hardCap,
            this.acceptedToken.address,
            {from: issuer});

        this.contributorRestrictions = await ContributorRestrictions.new(this.swarmPoweredFundraiseMock.address, {from: issuer});
        await this.swarmPoweredFundraiseMock.setContributorRestrictions(this.contributorRestrictions.address, {from: issuer});

        this.swarmPoweredFundraiseFinished = await SwarmPoweredFundraiseFinished.new(
            label,
            src20,
            tokenAmount,
            startDate,
            endDate,
            softCap,
            hardCap,
            this.acceptedToken.address,
            {from: issuer});
        this.contributorRestrictionsFinished = await ContributorRestrictions.new(this.swarmPoweredFundraiseFinished.address, {from: issuer});
        await this.swarmPoweredFundraiseFinished.setContributorRestrictions(this.contributorRestrictionsFinished.address);


        this.swarmPoweredFundraiseCanceled = await SwarmPoweredFundraiseCanceled.new(
            label,
            src20,
            tokenAmount,
            startDate,
            endDate,
            softCap,
            hardCap,
            this.acceptedToken.address,
            {from: issuer});
        this.contributorRestrictionsCanceled = await ContributorRestrictions.new(this.swarmPoweredFundraiseCanceled.address, {from: issuer});
        await this.swarmPoweredFundraiseCanceled.setContributorRestrictions(this.contributorRestrictionsCanceled.address);

        this.swarmPoweredFundraiseExpired = await SwarmPoweredFundraiseExpired.new(
            label,
            src20,
            tokenAmount,
            startDate,
            endDate,
            softCap,
            hardCap,
            this.acceptedToken.address,
            {from: issuer});
        this.contributorRestrictionsExpired = await ContributorRestrictions.new(this.swarmPoweredFundraiseExpired.address, {from: issuer});
        await this.swarmPoweredFundraiseExpired.setContributorRestrictions(this.contributorRestrictionsExpired.address);
    });

    describe('Fundraising whitelist functionality', () => {
        it('should be able to whitelist as a issuer', async function () {
            await this.contributorRestrictions.whitelistAccount(contributor, {from: issuer});

            assert.equal(await this.contributorRestrictions.isWhitelisted(contributor), true);
        });

        it('should be able to whitelist as a manager', async function () {
            await this.contributorRestrictions.whitelistAccount(contributor, {from: whitelistManager});

            assert.equal(await this.contributorRestrictions.isWhitelisted(contributor), true);
        });

        it('should not be able to whitelist as not-authorized account', async function () {
            await shouldFail.reverting.withMessage(this.contributorRestrictions.whitelistAccount(contributor, {from: contributor}),
                "Ownable: caller is not the issuer or manager");
        });

        it('should be able for contribution to automatically be moved to accepted contributions if contributor has been whitelist', async function () {
            const beforeBalanceETH = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor, {from: issuer});
            // contribute
            ({logs: this.logs} = await this.swarmPoweredFundraiseMock.send(amount, {from: owner}));
            expectEvent.inLogs(this.logs, 'Contribution', {
                from: owner,
                amount: new BN(amount),
                sequence: new BN(1),
                baseCurrency: constants.ZERO_ADDRESS,
            });
            const sequence = this.logs[0].args.sequence;

            // whitelist
            await this.contributorRestrictions.whitelistAccount(contributor, {from: issuer});

            const afterBalanceETH = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor, {from: issuer});
            assert.equal(beforeBalanceETH.add(amount).eq(afterBalanceETH), true);

            // increase historical balances only if contrition rule is met check
            const beforeHistoricalBalances = await this.swarmPoweredFundraiseMock.getHistoricalBalanceETH(sequence - 1, {from: issuer});
            const afterHistoricalBalances = await this.swarmPoweredFundraiseMock.getHistoricalBalanceETH(sequence, {from: issuer});
            assert.equal(beforeHistoricalBalances.add(amount).eq(afterHistoricalBalances), true);

            // move contributions to acc contribution if contribution rule are met check
            const accContribution = await this.swarmPoweredFundraiseMock.isContributionAccepted(sequence, {from: issuer});
            assert.equal(accContribution, true);
        });

        it('should be able to accept contribution if contributor is already on whitelist', async function () {
            const beforeBalanceETH = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor, {from: issuer});

            await this.contributorRestrictions.whitelistAccount(contributor, {from: issuer});

            ({logs: this.logs} = await this.swarmPoweredFundraiseMock.send(amount, {from: owner}));
            expectEvent.inLogs(this.logs, 'Contribution', {
                from: owner,
                amount: new BN(amount),
                sequence: new BN(1),
                baseCurrency: constants.ZERO_ADDRESS,
            });
            const sequence = this.logs[0].args.sequence;

            const afterBalanceETH = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor, {from: issuer});
            assert.equal(beforeBalanceETH.add(amount).eq(afterBalanceETH), true);

            // increase historical balances only if contrition rule is met check
            const beforeHistoricalBalances = await this.swarmPoweredFundraiseMock.getHistoricalBalanceETH(sequence - 1, {from: issuer});
            const afterHistoricalBalances = await this.swarmPoweredFundraiseMock.getHistoricalBalanceETH(sequence, {from: issuer});
            assert.equal(beforeHistoricalBalances.add(amount).eq(afterHistoricalBalances), true);

            // move contributions to acc contribution if contribution rule are met check
            const accContribution = await this.swarmPoweredFundraiseMock.isContributionAccepted(sequence, {from: issuer});
            assert.equal(accContribution, true);
        });

        it('should be able to de-whitelist as a issuer', async function () {
            await this.contributorRestrictions.whitelistAccount(contributor, {from: issuer});
            await this.contributorRestrictions.unWhitelistAccount(contributor, {from: issuer});

            assert.equal(await this.contributorRestrictions.isWhitelisted(contributor), false);
        });

        it('should be able to de-whitelist as a manager', async function () {
            await this.contributorRestrictions.whitelistAccount(contributor, {from: whitelistManager});
            await this.contributorRestrictions.unWhitelistAccount(contributor, {from: whitelistManager});

            assert.equal(await this.contributorRestrictions.isWhitelisted(contributor), false);
        });

        it('should not be able to de-whitelist as non-authorized account', async function () {
            await this.contributorRestrictions.whitelistAccount(contributor, {from: issuer});
            await shouldFail.reverting.withMessage(this.contributorRestrictions.unWhitelistAccount(contributor, {from: contributor}),
                "Ownable: caller is not the issuer or manager");
        });

        it('should not be able accept contribution if contributor is de-whitelisted', async function () {
            const beforeBalanceETH = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor, {from: issuer});
            // contribute
            ({logs: this.logs} = await this.swarmPoweredFundraiseMock.send(amount, {from: owner}));
            expectEvent.inLogs(this.logs, 'Contribution', {
                from: owner,
                amount: new BN(amount),
                sequence: new BN(1),
                baseCurrency: constants.ZERO_ADDRESS,
            });
            const sequence = this.logs[0].args.sequence;

            // whitelist
            await this.contributorRestrictions.whitelistAccount(contributor, {from: issuer});
            await this.contributorRestrictions.unWhitelistAccount(contributor, {from: issuer});

            const afterBalanceETH = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor, {from: issuer});
            assert.equal(beforeBalanceETH.add(amount).eq(afterBalanceETH), true);

            // increase historical balances only if contrition rule is met check
            const beforeHistoricalBalances = await this.swarmPoweredFundraiseMock.getHistoricalBalanceETH(sequence - 1, {from: issuer});
            const afterHistoricalBalances = await this.swarmPoweredFundraiseMock.getHistoricalBalanceETH(sequence, {from: issuer});
            assert.equal(beforeHistoricalBalances.add(amount).eq(afterHistoricalBalances), true);

            // move contributions to acc contribution if contribution rule are met check
            const accContribution = await this.swarmPoweredFundraiseMock.isContributionAccepted(sequence, {from: issuer});
            assert.equal(accContribution, false);
        });

        it('should not be able to whitelist if fundraising is finished', async function () {
            await shouldFail.reverting.withMessage(this.contributorRestrictionsFinished.whitelistAccount(contributor, {from: issuer}),
                "Account whitelisting failed: fundraising is finished");
        });

        it('should not be able to whitelist if fundraising is expired', async function () {
            await shouldFail.reverting.withMessage(this.contributorRestrictionsExpired.whitelistAccount(contributor, {from: issuer}),
                "Account whitelisting failed: fundraising is expired");
        });

        it('should not be able to whitelist if fundraising is canceled', async function () {
            await shouldFail.reverting.withMessage(this.contributorRestrictionsCanceled.whitelistAccount(contributor, {from: issuer}),
                "Account whitelisting failed: fundraising is canceled");
        });

        it('should not be able to de-whitelist if fundraising is finished', async function () {
            await shouldFail.reverting.withMessage(this.contributorRestrictionsFinished.unWhitelistAccount(contributor, {from: issuer}),
                "Account un-whitelisting failed: fundraising is finished");
        });

        it('should not be able to de-whitelist if fundraising is expired', async function () {
            await shouldFail.reverting.withMessage(this.contributorRestrictionsExpired.unWhitelistAccount(contributor, {from: issuer}),
                "Account un-whitelisting failed: fundraising is expired");
        });

        it('should not be able to de-whitelist if fundraising is canceled', async function () {
            await shouldFail.reverting.withMessage(this.contributorRestrictionsCanceled.unWhitelistAccount(contributor, {from: issuer}),
                "Account un-whitelisting failed: fundraising is canceled");
        });
    });
});
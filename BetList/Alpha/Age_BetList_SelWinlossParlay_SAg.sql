/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossParlay_SAg]
	@CustId			INT				= NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@Language		VARCHAR(2)		= 'E',
	@MoveBetsDay	SMALLDATETIME,
	@BetType		SMALLINT		= 9
AS

/*
	Created:
	Task: Betlist
	DB: DBAGE.bodb02
	Original:
	Revisions:
		- 20090407@Amy: get refno field instead of transid
		- 20090421@Henry: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@Henry: Change formula of commission
		- 20090618@Don: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency
		- 20091202@Henry: add 1 more column: winlostdate for selecting mix parlay detail
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101224@Johnson: change type of bettype to SMALLINT in temporary table
		- 20110810@Sophia: Add new parametter @Bettype for Combination parlay
		- 20110811@Sophia: Add new columns actual_stake and modds
		- 20110829@Sophia: Add new columns BetID
		- 20111216@Sophia: Remove function f_GetChoice
		- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
		- 20120927@Sophia: Get comstatus
		- 20130410@Lukas: get custid field
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160122@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20180329@Kos: Modify code to use index in mrecommend on bettrans14 range [#Redmine: 91150]
					- Change RefNo column data type from NVARCHAR(30) to BIGINT
					- Don't return betstatus, matchcode, homeid, awayid, leagueid, matchid, sporttype anymore
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
		- 20210129@Kos: Support God Of Fortune [Redmine: #149740]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SAgWinlossMP TABLE(
		CustId			INT,
		Username		NVARCHAR(30),
		BetType			SMALLINT,
		RefNo			BIGINT,
		TransId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		Status			NVARCHAR(10),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		AComm			MONEY,
		SComm			MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(25),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		ADiscount		SMALLMONEY,
		MDiscount		SMALLMONEY,
		SDiscount		SMALLMONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(20),
		IsNeutral		BIT,
		BetId			BIGINT,
		ComStatus		NVARCHAR(20),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		ExtraInfo		VARCHAR(1000)
	)

	DECLARE @TempFromDate DATETIME,
		@TempToDate DATETIME

	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO @SAgWinlossMP
		SELECT
			b.custid,
			b.username,
			b.bettype,
			b.refno,
			CASE
				WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
				ELSE b.betid
			END AS transid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm,
			(b.scomm - b.acomm) AS scomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.discount AS adiscount,
			b.adiscount AS mdiscount,
			b.sdiscount AS sdiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			CONVERT(BIT, 0) AS IsNeutral,
			b.betid,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			ISNULL(b.betcheck, '') AS BetCheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE
			b.srecommend = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.bettype = @BetType
			AND b.matchid = @BetType
			AND b.ruben = 1
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO @SAgWinlossMP
		SELECT
			b.custid,
			b.username,
			b.bettype,
			b.refno,
			CASE
				WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
				ELSE b.betid
			END AS transid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm,
			(b.scomm - b.acomm) AS scomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.discount AS adiscount,
			b.adiscount AS mdiscount,
			b.sdiscount AS sdiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			CONVERT(BIT, 0) AS IsNeutral,
			b.betid,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			ISNULL(b.betcheck, '') AS BetCheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE
			b.srecommend = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.bettype = @BetType
			AND b.matchid = @BetType
			AND b.ruben = 1
	END

	SELECT * FROM @SAgWinlossMP
	ORDER BY Status,
		Transid
END
GO

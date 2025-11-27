/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossParlay_MAg]
	@CustID			INT				= NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@bettype		SMALLINT		= 9
AS

/*
	Created: 
	Task : Betlist
	DB: DBAGE.bodb02

	Revisions:
		- 20090407@[HanhVu]: get refno field instead of transid
		- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@HiepVo: Change formula of commission
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency.
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
		- 20210129@Kos: Support God Of Fortune [Redmine: #149740]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
					- Remove param @Language
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20240222@Razor: Support Vitual Sports 4 [Redmine: #198619]
		- 20240723@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
		- 20241218@Razor: Support Direct Member [Redmine: #211969]
		- 20251029@Virgil: Support BetBuilder+ Hybrid Parlay [Redmine: #242378]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MAgWinlossMP TABLE(
		custid			INT,
		username		NVARCHAR(30),
		bettype			SMALLINT,
		refno			NVARCHAR(30),
		transid			BIGINT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		odds			MONEY,
		modds			MONEY,
		OddsSpread		MONEY,
		status			NVARCHAR(10),
		stake			MONEY,
		actual_stake	MONEY,
		winlost			MONEY,
		awinlost		MONEY,
		mwinlost		MONEY,
		swinlost		MONEY,
		playercomm		MONEY,
		comm			MONEY,
		acomm			MONEY,
		scomm			MONEY,
		transdate		DATETIME,
		winlostdate		DATETIME,
		betteam			NVARCHAR(25),
		apositiontaking	SMALLMONEY,
		mpositiontaking	SMALLMONEY,
		spositiontaking	SMALLMONEY,
		adiscount		SMALLMONEY,
		mdiscount		SMALLMONEY,
		sdiscount		SMALLMONEY,
		liveindicator	BIT,
		livehomescore	SMALLINT,
		liveawayscore	SMALLINT,
		IP				VARCHAR(45),
		isNeutral		BIT,
		betID			BIGINT,
		comstatus		NVARCHAR(20),
		BetCheck		NVARCHAR(50),
		transdesc		NVARCHAR(1000),
		ExtraInfo		VARCHAR(1000),
		DeviceType		TINYINT
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO @MAgWinlossMP
		(
			custid, username, bettype, refno, transid, hdp1, hdp2, odds, modds, OddsSpread, status, stake, actual_stake, winlost, awinlost,
			mwinlost, swinlost, playercomm, comm, acomm, scomm, transdate, winlostdate, betteam, apositiontaking, mpositiontaking, spositiontaking,
			adiscount, mdiscount, sdiscount, liveindicator, livehomescore, liveawayscore, IP, isNeutral, betID, comstatus, BetCheck, transdesc, ExtraInfo, DeviceType
		)
		SELECT
			b.custid,
			b.username,
			b.bettype,
			CONVERT(NVARCHAR,b.refno),
			b.transid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.oddsspread,
			b.status,
			b.stake,
			b.actual_stake,
			(b.winlost-actual_stake),
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
			CASE
				WHEN b.recommend IN (-3, -4) THEN 0
				ELSE b.discount
			END AS adiscount,
			b.adiscount AS mdiscount,
			b.sdiscount AS sdiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP,
			CONVERT(BIT,0) AS IsNeutral,
			b.betID,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			ISNULL(b.betcheck, '') AS BetCheck,
			IIF(b.bettype = 29 AND b.OddsSpread = 3, ISNULL(b.transdesc, ''),'') AS transdesc,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			b.DeviceType
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE
			b.MRecommend = @CustID AND
			b.Winlostdate >= @FromDate AND
			b.Winlostdate <= @ToDate AND
			b.Ruben = 1 
			AND 1 = CASE
						WHEN @BetType  = 29 AND b.bettype = @BetType THEN 1
						WHEN @BetType IN (2799, 10449, 11099) AND b.bettype IN (2799, 10449, 11099) THEN 1
						ELSE 0 
					END
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @MAgWinlossMP
		(
			custid, username, bettype, refno, transid, hdp1, hdp2, odds, modds, OddsSpread, status, stake, actual_stake, winlost, awinlost,
			mwinlost, swinlost, playercomm, comm, acomm, scomm, transdate, winlostdate, betteam, apositiontaking, mpositiontaking, spositiontaking,
			adiscount, mdiscount, sdiscount, liveindicator, livehomescore, liveawayscore, IP, isNeutral, betID, comstatus, BetCheck, transdesc, ExtraInfo, DeviceType
		)
		SELECT
			b14.custid,
			b14.username,
			b14.bettype,
			CONVERT(NVARCHAR,b14.refno),
			b14.transid,
			b14.hdp1,
			b14.hdp2,
			b14.odds,
			b14.modds,
			b14.oddsspread,
			b14.status,
			b14.stake,
			b14.actual_stake,
			(b14.winlost - b14.actual_stake),
			b14.awinlost,
			b14.mwinlost,
			b14.swinlost,
			b14.playercomm,
			(b14.comm - b14.playercomm) AS comm,
			(b14.acomm - b14.comm) AS acomm,
			(b14.scomm - b14.acomm) AS scomm,
			b14.transdate,
			b14.winlostdate,
			b14.betteam,
			b14.apositiontaking,
			b14.mpositiontaking,
			b14.spositiontaking,
			CASE
				WHEN b14.recommend IN (-3, -4) THEN 0
				ELSE b14.discount
			END AS adiscount,
			b14.adiscount AS mdiscount,
			b14.sdiscount AS sdiscount,
			b14.liveindicator,
			b14.livehomescore,
			b14.liveawayscore,
			b14.IP,
			CONVERT(BIT,0) AS IsNeutral,
			b14.betID,
			CASE WHEN b14.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			ISNULL(b14.betcheck, '') AS BetCheck,
			IIF(b14.bettype = 29 AND b14.OddsSpread = 3, ISNULL(b14.transdesc, ''),'') AS transdesc,
			ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
			b14.DeviceType
		FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
		WHERE
			b14.MRecommend = @CustID AND
			b14.Winlostdate >= @FromDate AND
			b14.Winlostdate <= @ToDate AND
			b14.Ruben = 1
			AND 1 = CASE
						WHEN @BetType  = 29 AND b14.bettype = @BetType THEN 1
						WHEN @BetType IN (2799, 10449, 11099) AND b14.bettype IN (2799, 10449, 11099) THEN 1
						ELSE 0 
					END
	END

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM @MAgWinlossMP WHERE BetType = 29 AND BetTeam = '1')
	BEGIN
		UPDATE b
		SET
			b.Odds = bpr.Odds,
			b.Modds = bpr.mOdds,
			b.TransDesc = IIF(b.OddsSpread = 3, b.TransDesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
		FROM @MAgWinlossMP AS b
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29 AND b.BetTeam = '1'
	END

	SELECT 
		custid,
		username,
		bettype,
		refno,
		transid,
		hdp1,
		hdp2,
		odds,
		modds,
		OddsSpread,
		status,
		stake,
		actual_stake,
		winlost,
		awinlost,
		mwinlost,
		swinlost,
		playercomm,
		comm,
		acomm,
		scomm,
		transdate,
		winlostdate,
		betteam,
		apositiontaking,
		mpositiontaking,
		spositiontaking,
		adiscount,
		mdiscount,
		sdiscount,
		liveindicator,
		livehomescore,
		liveawayscore,
		IP,
		isNeutral,
		betID,
		comstatus,
		BetCheck,
		transdesc,
		ExtraInfo,
		DeviceType,
		'' betstatus,
		'' matchcode,
		0 homeid,
		0 awayid,
		0 leagueid,
		0 matchid,
		0 sporttype
	FROM @MAgWinlossMP
	ORDER BY Status ASC, Transid ASC
END
GO

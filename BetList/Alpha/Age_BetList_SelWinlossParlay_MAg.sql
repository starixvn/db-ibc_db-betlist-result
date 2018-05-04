/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossParlay_MAg]
	@CustID			INT				= NULL,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@Language		VARCHAR(2)		= 'E',
	@MoveBetsDay	SMALLDATETIME,
	@bettype		SMALLINT		= 9
AS

/*
	Created: 
	Task : Betlist
	DB: DBAGE.bodb02
	Original:
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
		IP				VARCHAR(20),
		isNeutral		BIT,
		betID			BIGINT,
		comstatus		NVARCHAR(20),
		BetCheck		NVARCHAR(50),
		transdesc		NVARCHAR(1000)
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO @MAgWinlossMP 
		SELECT
			b.custid,
			b.username,
			b.bettype,
			CONVERT(NVARCHAR,b.refno),
			CASE WHEN ISNULL(b.betid,0) = 0 THEN b.transid ELSE b.betid END AS transid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
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
			b.discount AS adiscount,
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
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE
			b.MRecommend = @CustID AND
			b.Winlostdate >= @FromDate AND
			b.Winlostdate <= @ToDate AND
			b.Bettype = @bettype AND
			b.matchid = @bettype AND
			b.Ruben = 1
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @MAgWinlossMP 
		SELECT
			b.custid,
			b.username,
			b.bettype,
			CONVERT(NVARCHAR,b.refno),
			CASE WHEN ISNULL(b.betid,0) = 0 THEN b.transid ELSE b.betid END AS transid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
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
			b.discount AS adiscount,
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
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE
			b.MRecommend = @CustID AND
			b.Winlostdate >= @FromDate AND
			b.Winlostdate <= @ToDate AND
			b.Bettype = @bettype AND
			b.matchid = @bettype AND
			b.Ruben = 1
	END

	SELECT 
		*,
		'' betstatus,
		'' matchcode,
		0 homeid,
		0 awayid,
		0 leagueid,
		0 matchid,
		0 sporttype
	FROM @MAgWinlossMP
	ORDER BY Status, Transid
END




GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossParlay_MAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossParlay_MAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossParlay_MAg] TO [vnteam]
GO

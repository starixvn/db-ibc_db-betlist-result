/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[U3_BetsSelBetList_Old]
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@CustId		INT,
	@BetType	INT = 0
AS

/*
	Created: 20100123@[Henry]
	Task: Get Bet List from Archive
	DB: DBARC.bodb_Archive
	Original: Acc_BetsSelBetList_Old
	Revisions:
		- 20170725@Kos: Fix CheckBet issue [#Redmine: 80453]
					- Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20170810@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20201224@Kos: Support Happy 5 Linked Games [Redmine: #146540]
					- Don't support Live Casino, Bingo, Lucky 3 anymore
					- Dont return data table @DetailData anymore
					- Don't return column Race, FinalOdds, FinalOdds2, AllowDelete, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, VirtualRate, IsShowOTExRate,
						SPositionTaking2, MPositionTaking2, APositionTaking2
		- 20210705@Razor: Show Odds for Happy 5 Linked Games [Redmine: #154704]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211025@Razor: Decompress IP on BK range [Redmine: #90903]
		- 20211223@Razor: Support Third Party Result API [Redmine: #165815]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (3, 0, 0, 2, '', '', @IsTest)
	WHERE @BetType = 0 OR BetType = @BetType

	DECLARE @Data TABLE (
		BetType				SMALLINT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(50),
		EventDate			SMALLDATETIME,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		HomeId				INT, 
		AwayId				INT, 
		SettleTime			DATETIME,
		Hdp1				SMALLMONEY, 
		Hdp2				SMALLMONEY, 
		Odds				MONEY,
		OddsType			TINYINT,
		Status				NVARCHAR(50),
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(10),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		LiveIndicator		BIT,
		MOdds				MONEY,
		CustId				INT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		FinalHomeScore		SMALLINT,
		FinalAwayScore		SMALLINT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(1),
		MatchId				INT,
		IsNeutral			BIT,
		WinLost				MONEY,
		Commission			MONEY,
		SComm				MONEY,	
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		CurrencyId			TINYINT,
		SiteId				VARCHAR(20)
	)

	-- Number Game
	IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1)
	BEGIN
		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0),
			b.refno,
			m.matchcode,
			m.eventdate,
			b.sdiscount,
			b.adiscount,
			b.discount,
			m.homeid,
			m.awayid,
			ISNULL(b.checktime,'') settleTime,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus, 
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.spositiontaking,
			b.mpositiontaking,
			b.apositiontaking,
			b.liveindicator,
			b.modds,
			b.custid,
			b.livehomescore,
			b.liveawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.leagueid,
			m.sporttype,
			dp.ip,
			b.betfrom,
			b.matchid,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS winlost,
			b.playercomm AS commission,
			(b.scomm - b.acomm),
			(b.acomm - b.comm),
			(b.comm - b.playercomm),
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			m.showtime,
			b.winlostdate,
			'' AS BetCheck,
			'' AS TransDesc,
			0 AS CurrencyId,
			'' AS SiteId
		FROM
			dbo.bettrans_bk AS b WITH (NOLOCK)
			CROSS APPLY bodb02.dbo.f_IP_Decompress(b.Ip) AS dp
			INNER JOIN dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @ToDate
			AND b.custid = @CustId
			AND s.EventType = 1
	END

	-- Happy 5 Linked Games
	IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 0)
	BEGIN
		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetID,
			b.refno,
			'' AS matchcode,
			'' AS eventdate,
			b.sdiscount,
			b.adiscount,
			b.discount,
			0 AS homeid,
			0 AS awayid,
			'' AS settleTime,
			0 AS hdp1,
			0 AS hdp2,
			b.odds AS odds,
			0 AS OddsType,
			b.status,
			'' AS comstatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			'' AS betteam,
			b.spositiontaking,
			b.mpositiontaking,
			b.apositiontaking,
			0 AS liveindicator,
			0 AS modds,
			b.custid,
			0 AS livehomescore,
			0 AS liveawayscore,
			0,
			0,
			0 AS leagueid,
			b.matchid AS sporttype,
			dp.ip,
			b.betfrom,
			0 AS matchid,
			CONVERT(BIT, 0) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS commission,
			(b.scomm - b.acomm) AS scomm,
			(b.acomm - b.comm) AS acomm,
			(b.comm - b.playercomm) AS comm,
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			'' AS showtime,
			b.winlostdate,
			ISNULL(b.betcheck, '') AS BetCheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			b.currency,
			b.betdaqid
		FROM dbo.bettrans_bk AS b WITH (NOLOCK)
			CROSS APPLY bodb02.dbo.f_IP_Decompress(b.Ip) AS dp
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @ToDate
			AND b.custid = @CustId
			AND s.EventType = 0
	END

	SELECT b.*,
		ex.currency
	FROM @Data AS b
		LEFT JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
		LEFT JOIN bodb02.dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	ORDER BY b.TransId ASC
END
GO

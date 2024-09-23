/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossHR_SAg]
	@CustId			INT				= NULL,		-- SuperID
	@BetType		INT,
	@Race			VARCHAR(20),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created: 
	Task: Betlist
	DB: DBAGE.bodb02
	Original:
	Revisions:
		- 20090407@Amy: remove refno
		- 20090421@Henry: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@Henry: Change formula of commission
		- 20090530@Henry:  Get more data from bettransm for HR
		- 20090618@Don: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency
		- 20091024@[MinhNguyen]: get modds, finalodds
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101224@Johnson: change type of bettype to SMALLINT in temporary table
		- 20120927@Sophia: Get comstatus
		- 20130306@Elodie: Add bet list of Virtual HR
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20180201@Kos: Don't support Racing anymore [Redmine: #86086]
		- 20200625@Kos: Integrate archive process for table VSRaceInfo [Redmine: #135963]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20240920@Razor: Support VS2 - Racing sports [Redmine: #211092]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Horse Racing, Virtual Horse Racing only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Get group bettype
	DECLARE @GroupBetType TABLE (BetType INT, GroupTypeId INT)

	INSERT INTO @GroupBetType
	SELECT
		bettype,
		GroupTypeId
	FROM dbo.f_GroupBettype()
	
	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE 
		EventType = 3
		AND (Bettype = @BetType
			OR EXISTS (SELECT 1 FROM @GroupBetType WHERE GroupTypeId = @BetType AND BetType = BetType))

	DECLARE @AgWinlossHR TABLE (
		SportType		SMALLINT,
		Username		NVARCHAR(30),
		CustId			INT,
		BetType			SMALLINT,
		TransId			BIGINT,
		Race			VARCHAR(20),
		MatchCode		VARCHAR(30),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(10),
		Stake			MONEY,
		WinLost			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		AComm			MONEY,
		SComm			MONEY,
		TransDate		DATETIME,
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
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(45),
		BetStatus		VARCHAR(20),
		IsNeutral		BIT,
		ComStatus		NVARCHAR(20),
		RefNo			NVARCHAR(50),
		ShowTime		NVARCHAR(50),
		DeviceType		TINYINT,
		TransDesc		NVARCHAR(1000),
		WinLostDate		SMALLDATETIME
	)

	DECLARE @TempFromDate DATETIME,
		@TempToDate DATETIME

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO @AgWinlossHR
		SELECT
			r.SportType,
			b.username,
			b.custid,
			b.bettype,
			b.transid,
			b.oddsid AS race,
			'' AS matchcode,
			0 AS homeid,
			0 awayid,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.odds,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake),
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm ,
			(b.scomm - b.acomm) AS scomm,
			b.transdate,
			b.betteam,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking, 
			b.discount,
			b.adiscount,
			b.sdiscount,
			0,
			b.livehomescore,
			b.liveawayscore,
			r.LeagueID,
			b.matchid, 
			b.ip,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			b.refno,
			'' AS showtime,
			b.DeviceType,
			b.transdesc,
			b.winlostdate
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = b.matchid
		WHERE b.srecommend = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.matchid = @Race
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO @AgWinlossHR
		SELECT
			r.sporttype,
			b.username,
			b.custid,
			b.bettype,
			b.transid,
			b.oddsid AS race,
			'' matchcode,
			0 homeid,
			0 awayid,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.odds,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake),
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm,
			(b.scomm - b.acomm) AS scomm,
			b.transdate,
			b.betteam,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.discount,
			b.adiscount,
			b.sdiscount,
			0,
			b.livehomescore,
			b.liveawayscore,
			r.leagueID,
			b.matchid,
			b.ip,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			b.refno,
			'' AS showtime,
			b.DeviceType,
			b.transdesc,
			b.winlostdate
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
			INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = b.matchid
		WHERE b.srecommend = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.matchid = @Race
	END

	SELECT * FROM @AgWinlossHR
	ORDER BY Status ASC, TransId ASC
END
GO

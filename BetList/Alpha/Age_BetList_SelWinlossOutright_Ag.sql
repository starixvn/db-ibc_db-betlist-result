/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossOutright_Ag]
	@CustId			INT				= NULL,		-- Agent CustId
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@LeagueId		INT				= NULL,
	@Language		VARCHAR(2)		= 'E',
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created:
	Task : get bet tickets for outright, horse racing
	DB: DBAGE.bodb02
	Original:

	Revisions:
		- 20090407@[HanhVu]: remove redundant transid field
		- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@HiepVo: Change formula of commission
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101224@Johnson: change type of bettype to SMALLINT in temporary table
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120927@Sophia: Get comstatus
		- 20150420@Tom: Add @leagueID parameter
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20170605@Kos: Return column CustId for Microsite bet list [#Redmine: 66992]
					- Prevent data duplication during Move Bet process
		- 20210706@Razor: Display Decimal Odds for Decimal Odds Only Bettypes [#Redmine: 157545]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @AgWinlossOutright TABLE (
		SportType		SMALLINT,
		CustId			INT,
		Username		NVARCHAR(30),
		BetType			SMALLINT,
		TransId			BIGINT,
		MatchCode		VARCHAR(30),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
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
		ADiscount		SMALLMONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(45),
		BetStatus		VARCHAR(20),
		IsNeutral		BIT,
		ComStatus		NVARCHAR(20),
		DeviceType		TINYINT
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO @AgWinlossOutright 
		SELECT
			l.sporttype,
			b.custid,
			b.username,
			b.bettype,
			b.transid,
			m.matchcode,
			m.teamID AS HomeId,
			0 AS AwayId,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake) AS WinLost,
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
			b.discount AS adiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueid,
			b.matchid,
			b.ip,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			b.DeviceType
		FROM dbo.bettrans AS b WITH (NOLOCK) 
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE b.Recommend = @CustId
			AND b.Winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.Bettype = 10
			AND b.Ruben = 1
			AND (@LeagueId IS NULL OR m.leagueID = @LeagueId)
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		INSERT INTO @AgWinlossOutright
		SELECT
			l.sporttype,
			b.custid,
			b.username,
			b.bettype,
			b.transid,
			m.matchcode,
			m.teamid AS HomeId,
			0 AS AwayId,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.status,
			b.stake,
			(b.winlost - b.actual_stake) AS WinLost,
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
			b.discount AS adiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueid,
			b.matchid,
			b.ip,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			b.DeviceType
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK) 
			INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE b.Recommend = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND b.bettype = 10
			AND b.ruben = 1
			AND (@LeagueId IS NULL OR m.leagueID = @LeagueId)
	END

	SELECT * FROM @AgWinlossOutright
	ORDER BY Status, Transid
END

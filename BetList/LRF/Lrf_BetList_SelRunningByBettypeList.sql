USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelRunningByBettypeList]
	@AgentList	VARCHAR(MAX),
	@BetType	VARCHAR(50),
	@PageSize	INT				= 1000,
	@PageIndex	INT				= 1,
	@TotalRows	INT				= 0 OUTPUT
AS

/*
	Created: Hannah@20140708
	Task: Betlist
	DB: DBEXT.bodb02
	Original: [Lrf_BetList_SelRunningByBettype]
	Revisions:
		- 20140708@Hannah: Clone from Lrf_BetList_SelRunningByBettype to support muilti bettype
		- 20140925@Jim: Restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
		- 20150123@Jim: Support base on Currency GBP
		- 20150414@Jim: Support betradar
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160412@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20161003@Kos: Remove Live Casino code [Redmine: #65045]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

	IF ISNULL(@BetType, '') = ''
		SET @BetType = ''

	DECLARE @tblbettype AS TABLE (bettype INT)

	INSERT INTO @tblbettype (bettype)
	SELECT CONVERT(INT,VAL) AS bettype
	FROM strSplit(@BetType, ',')

	CREATE TABLE #Data (
		CustId			INT,
		SportType		INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			VARCHAR(50),
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	INT,
		Discount		DECIMAL(9,8),
		LeagueId		INT,
		Ip				NVARCHAR(30),
		IsNeutral		BIT,
		OddsType		TINYINT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		StatusId		INT,
		PlayerComm		MONEY,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT
	)

	IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype IN (9, 29))
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			0 AS SportType,
			b.username,
			b.bettype,
			CASE
				WHEN b.bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE betid END
			END AS transid,
			ISNULL(b.betid, 0),
			b.refno,
			'' AS matchcode,
			0 AS homeID,
			0 AS awayID,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			0 AS livehomescore,
			0 AS liveawayscore,
			0 AS liveindicator,
			b.discount,
			0 AS LeagueID,
			b.ip,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.statusid,
			b.playercomm,
			'' AS ShowTime,
			ISNULL(b.betcheck, '') AS BetCheck,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @tblbettype AS bt ON b.bettype = bt.bettype
		WHERE
			b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND b.bettype IN (9, 29)
			AND b.matchid = bt.bettype
			AND b.statusID IN (0, 1)
			AND b.ruben = 0
		ORDER BY
			b.status,
			b.transid
	END
	ELSE IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype = 10)	-- Outright
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			l.sporttype,
			b.username,
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0),
			b.refno,
			m.matchcode,
			m.teamid AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			b.discount,
			m.leagueid,
			b.ip,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.statusid,
			b.playercomm,
			'' AS ShowTime,
			'' AS BetCheck,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON  b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		WHERE
			b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND b.bettype = 10
			AND b.statusID = 0
		ORDER BY
			b.status,
			b.transid
	END
	ELSE IF EXISTS (SELECT 1 FROM @tblbettype WHERE bettype <= 19000)
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			m.sporttype,
			b.username,
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0),
			b.refno,
			m.matchcode,
			m.homeid,
			m.awayid,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			b.discount,
			m.leagueid,
			b.ip,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.statusid,
			b.playercomm,
			ISNULL(m.showtime, '') AS showtime,
			b.betcheck,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]', 'MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @tblbettype AS bt ON b.bettype = bt.bettype
		WHERE
			b.recommend IN (SELECT CustId FROM @TempAg)
			AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
			AND b.bettype <= 19000
			AND b.statusID IN (0, 1)
			AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
		ORDER BY
			b.status,
			b.transid
	END

	DECLARE @RowStart	INT,
		@RowEnd			INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

	IF @TotalRows = 0
	BEGIN
		SELECT @TotalRows = COUNT(transid)
		FROM #Data
	END

	SELECT A.*
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.TransId) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
				b.*,
				b.Stake * e.USD AS StakeUSD,
				b.Stake * e.EUR AS StakeEUR,
				b.Stake * e.GBP AS StakeGBP,
				b.Actual_Stake * e.USD AS Actual_StakeUSD,
				b.Actual_Stake * e.EUR AS Actual_StakeEUR,
				b.Actual_Stake * e.GBP AS Actual_StakeGBP,
				b.PlayerComm * e.USD AS PlayerCommUSD,
				b.PlayerComm * e.EUR AS PlayerCommEUR,
				b.PlayerComm * e.GBP AS PlayerCommGBP,
				b.OriginalStake * e.USD AS OriginalStakeUSD,
				b.OriginalStake * e.EUR AS OriginalStakeEUR,
				b.OriginalStake * e.GBP AS OriginalStakeGBP
			FROM #Data AS b
				INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = b.CustId
				INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) AS e ON e.exchangeid = b.Currency
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #Data
END



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelRunningByBettypeList] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelRunningByBettypeList] TO vnteam
GO

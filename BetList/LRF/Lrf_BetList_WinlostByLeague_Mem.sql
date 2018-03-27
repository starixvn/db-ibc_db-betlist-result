USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_WinlostByLeague_Mem]    Script Date: 4/20/2015 12:14:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_WinlostByLeague_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@Odds			MONEY			= 0,
	@LeagueId		INT,
	@MatchId		INT				= 0,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT,
	@FromDate		SMALLDATETIME	= NULL,
	@ToDate			SMALLDATETIME	= NULL,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@ShowWin		BIT				= 1,
	@ShowLoss		BIT				= 1,
	@ShowDraw		BIT				= 1,
	@ShowSB			BIT				= 1,
	@ShowBA			BIT				= 1
AS

/*
	Created: 20140102@Florent
	Task: Betlist
	DB: DBEXT.bodb02
	Original:[Lrf_BetList_MatchWL_Bettype_8828]
	Revisions:
		- 20140207@Florent: add filter ShowBA and ShowSB
		- 20140214@Florent: add filter by match
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150128@Winnie: Add base currency GBP
		- 20150408@Winnie: Apply spottype bettype matrix & add 60 bettypes betradar
		- 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20170227@Kos: Support sub licensees [#Redmine: 71679]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]

	Param's Explanation: 
		- @AgentList : Agent List, XML format (<ROOT><Agent AgentId="12345" Currency="3"/></ROOT>)
		- @CustID : Customer Number
		- @Odds : decimals odds, default >= 0
		- @LeagueID : LeagueID, Number
		- @PageSize : Number rows of one fage, for faging
		- @PageIndex : Index of paging
		- @TotalRows : Number rows of output
		- @FromDate : time range
		- @ToDate :time range
		- @MoveBetsDay : that day we use bettrans14
		- @BalanceUpDay : that day we use bettrans_bk
		- @ShowWin : show only win bet ,default = 1
		- @ShowLoss: show only loss bet,default = 1
		- @ShowDraw : show only draw bet,default = 1
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

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT, EventType INT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (901, 902, 903, 904, 911, 912, 913, 914)

	CREATE TABLE #Data (
		SportType		INT,
		Username		NVARCHAR(50),
		CustId			INT,
		BetType			INT,
		LeagueId		INT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Odds2			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			VARCHAR(50),
		LiveIndicator	INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		MatchId			INT,
		StatusId		INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		OddsType		INT,
		BetId			BIGINT,
		Currency		SMALLINT,
		RefNo			BIGINT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT
	)

	DECLARE @Status AS TABLE (StatusID INT)

	IF @ShowWin = 1
	BEGIN
		INSERT INTO @status
		SELECT 112

		INSERT INTO @status
		SELECT 114
	END

	IF @ShowLoss = 1
	BEGIN
		INSERT INTO @status
		SELECT 113

		INSERT INTO @status
		SELECT 115
	END

	IF @ShowDraw = 1
		INSERT INTO @status
		SELECT 111

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.odds,
				CASE
					WHEN ( b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120 )
						THEN CASE
								WHEN b.oddstype = 1 THEN b.odds + 1 --decimal
								WHEN b.oddstype = 2 THEN b.odds + 1 --hongkong to decimal
								WHEN b.oddstype IN (3, 4) THEN --malay and indo to decimal
									CASE
										WHEN b.odds < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN b.odds >= 0 THEN (1 + b.odds)
									END
								WHEN b.oddstype = 5 THEN --american odds to decimal
									CASE
										WHEN (b.odds * 100) < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0 THEN 2
										WHEN (b.odds * 100) > 0 THEN (1 + b.odds)
									END
								END
					ELSE b.odds
				END AS odds2,
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.statusID,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @LeagueID
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (SELECT * FROM @status)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustID
				AND b.tpositiontaking = 0	-- getBA
				AND (@MatchId = 0 OR m.matchid = @MatchId)
			ORDER BY b.status,
				b.transid
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.odds,
				CASE
					WHEN ( b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120 )
						THEN CASE
								WHEN b.oddstype = 1 THEN b.odds + 1 --decimal
								WHEN b.oddstype = 2 THEN b.Odds + 1 --hongkong to decimal
								WHEN b.oddstype IN (3, 4) THEN --malay and indo to decimal
									CASE 
										WHEN b.odds < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN b.odds >= 0 THEN (1 + b.odds)
									END
								WHEN b.oddstype = 5 THEN --american odds to decimal
									CASE 
										WHEN (b.odds * 100) < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0 THEN 2
										WHEN (b.odds * 100) > 0 THEN (1 + b.odds)
									END
							END
					ELSE b.odds
				END odds2,
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.statusID,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @LeagueID
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN ( SELECT * FROM @status )
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustID
				AND b.tpositiontaking <> 0
				AND (@MatchId = 0 OR m.matchid = @MatchId)
			ORDER BY b.status,
				b.transid
		END
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueID,
				b.transid,
				m.matchcode,
				m.homeID,
				m.awayID,
				b.hdp1,
				b.hdp2,
				b.Odds,
				CASE
					WHEN ( b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120 )
						THEN CASE 
								WHEN b.oddstype = 1 THEN b.odds + 1 --decimal
								WHEN b.oddstype = 2 THEN b.Odds + 1 --hongkong to decimal
								WHEN b.oddstype IN (3, 4) THEN --malay and indo to decimal
									CASE 
										WHEN b.odds < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN b.odds >= 0 THEN (1 + b.odds)
									END
								WHEN b.oddstype = 5 THEN --american odds to decimal
									CASE 
										WHEN (b.odds * 100) < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0 THEN 2
										WHEN (b.odds * 100) > 0 THEN (1 + b.odds)
									END
							END
					ELSE b.odds
				END odds2,
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.statusID,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CASE
					WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime, '')
					ELSE ''
				END AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @leagueID
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN ( SELECT * FROM @status )
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustID
				AND b.tpositiontaking = 0
				AND (@MatchId = 0 OR m.matchid = @MatchId)
			ORDER BY b.status,
				b.transid
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.username,
				b.custid,
				b.bettype,
				m.leagueid,
				b.transid,
				m.matchcode,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.Odds,
				CASE
					WHEN ( b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120 )
						THEN CASE
								WHEN b.oddstype = 1 THEN b.odds + 1 --decimal
								WHEN b.oddstype = 2 THEN b.Odds + 1 --hongkong to decimal
								WHEN b.oddstype IN (3, 4) THEN --malay and indo to decimal
									CASE 
										WHEN b.odds < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN b.odds >= 0 THEN (1 + b.odds)
									END
								WHEN b.oddstype = 5 THEN --american odds to decimal
									CASE 
										WHEN (b.odds * 100) < 0 THEN (1 - CAST(1 AS FLOAT) / CAST(b.odds AS FLOAT))
										WHEN (b.odds * 100) % 2 = 0 THEN 2
										WHEN (b.odds * 100) > 0 THEN (1 + b.odds)
									END
							END
					ELSE b.odds
				END odds2,
				b.status,
				b.stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.matchid,
				b.statusID,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				b.oddstype,
				b.betid,
				b.currency,
				b.refno,
				CASE 
					WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime, '')
					ELSE ''
				END AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @leagueID
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.statusID IN (SELECT * FROM @status)
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustID
				AND b.tpositiontaking <> 0
				AND (@MatchId = 0 OR m.matchid = @MatchId)
			ORDER BY b.status,
				b.transid
		END
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @todate

		DECLARE @sql		NVARCHAR(MAX),
			@OPENQUERY		NVARCHAR(4000),
			@TSQL			NVARCHAR(4000),
			@LinkedServer	NVARCHAR(40)

		SET @LinkedServer = 'DBARC'
		SET @OPENQUERY = 'SELECT * FROM OPENQUERY(' + @LinkedServer + ','''

		IF @showBA = 1
		BEGIN
			SET @TSQL = ''
			SET @TSQL = '
				WITH cte_match
				AS (
				SELECT m.matchid,m.sporttype,m.leagueID,m.matchcode,m.homeID,m.awayID,m.betstatus,
					m.ShowTime,m.isNeutral
				FROM bodb_archive.dbo.match_bk m WITH(NOLOCK)
				WHERE m.leagueid =' + CAST(@leagueid AS VARCHAR) + '
					AND EventDate BETWEEN ''''' + CAST(@fromdate AS VARCHAR) + ''''' AND ''''' + CAST(@todate AS VARCHAR) + ''''')

				SELECT m.sporttype,
					'''''''' username,
					b.custid,
					b.bettype,
					m.leagueID,
					b.transid,
					m.matchcode,
					m.homeID,
					m.awayID,
					CONVERT(FLOAT, b.hdp1) AS hdp1,
					CONVERT(FLOAT, b.hdp2) AS hdp2,
					b.Odds,
					CASE
						WHEN (b.bettype IN (1,2,3,7,12,8,20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120)
							THEN
								CASE
									WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3,4) THEN --malay and indo to decimal
										CASE 
											WHEN b.odds < 0 THEN (1 -  CAST(1 AS float) / CAST(b.odds AS float))
											WHEN b.odds >= 0 THEN (1 + b.odds)
										END
									WHEN OddsType = 5 THEN --american odds to decimal
										CASE
											WHEN (b.odds * 100) < 0 THEN (1- CAST (1 AS float)/ CAST (b.odds AS float))
											WHEN (b.odds * 100) % 2 = 0 THEN 2
											WHEN (b.odds * 100) > 0 THEN (1 + b.odds)
										END 
								END
						ELSE b.Odds
					END odds2,
					b.status,
					b.stake,
					(b.winlost-actual_stake) winlost,
					0 AS LicenseeWL,
					b.comm,
					b.playercomm,
					b.transdate,
					b.winlostdate,
					b.betteam,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.matchid,
					b.statusID,
					m.betstatus,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					b.OddsType,
					b.betid,
					b.currency,
					b.refno,
					m.ShowTime,
					b.betcheck,
					ISNULL(b.transdesc, '''''''') AS transdesc,
					ISNULL(b.betdaqid, -1) AS BetdaqId,
					ISNULL(b.ExtraInfo, '''''''') AS ExtraInfo,
					CASE
						WHEN b.ExtraInfo LIKE ''''%p25%'''' THEN
							ISNULL(CAST((''''<xml>'''' + b.ExtraInfo + ''''</xml>'''') AS XML).value(''''data(/xml/p25/@s)[1]'''',''''MONEY''''), 0)
						ELSE 0
					END AS OriginalStake,
					CASE
						WHEN b.stake <> 0 THEN -1
						ELSE 0
					END AS OriginalBetType,
					0 AS WalletType,
					0 AS RefCode
				FROM
					bodb_archive.dbo.bettrans_bk b WITH (NOLOCK, INDEX=IX_CUSTID)
					INNER JOIN cte_match m ON b.matchid = m.matchid
				WHERE b.winlostdate BETWEEN ''''' 
					+ CAST(@FromDate AS VARCHAR) + '''''' + ' AND ''''' + CAST(@TempToDate AS VARCHAR) + '''''
					AND (b.bettype < 31
						OR (b.bettype BETWEEN 121 AND 999)
						OR (b.bettype BETWEEN 1301 AND 1399))
					AND b.statusID IN (111, 112, 113, 114, 115)
					AND b.Custid =' + CAST(@CustId AS VARCHAR) + '
					AND b.tpositiontaking = 0
					AND (' + CAST(@MatchId AS VARCHAR) + '=0 OR m.matchid=' + CAST(@MatchId AS VARCHAR) + ')
					'')'

			SELECT @sql = @OPENQUERY + @TSQL

			INSERT INTO #Data
			EXEC(@sql)
		END

		IF @ShowSB = 1
		BEGIN
			SET @TSQL = ''
			SET @TSQL = '
				WITH cte_match
				AS (
				SELECT m.matchid,m.sporttype,m.leagueID,m.matchcode,m.homeID,m.awayID,m.betstatus,
					m.ShowTime,m.isNeutral
				FROM bodb_archive.dbo.match_bk m WITH (NOLOCK)
				WHERE m.leagueid =' + CAST(@leagueid AS VARCHAR) + '
					AND EventDate between ''''' + CAST(@fromdate AS VARCHAR) + '''''' + ' AND ''''' + CAST(@todate AS VARCHAR) + ''''')

				SELECT m.sporttype,
					'''''''' username,
					b.custid,
					b.bettype,
					m.leagueID,
					b.transid,
					m.matchcode,
					m.homeID,
					m.awayID,
					CONVERT(FLOAT, b.hdp1) AS hdp1, 
					CONVERT(FLOAT, b.hdp2) AS hdp2,
					b.Odds,
					CASE WHEN (b.bettype IN (1,2,3,7,12,8,20)
								OR b.bettype BETWEEN 81 AND 88
								OR b.bettype BETWEEN 90 AND 120)
							THEN 
								CASE 
									WHEN b.OddsType = 1 THEN b.odds + 1 --decimal
									WHEN b.OddsType = 2 THEN b.Odds + 1 --hongkong to decimal
									WHEN b.OddsType IN (3,4) THEN --malay and indo to decimal
										CASE 
											WHEN b.odds < 0 THEN (1 -  CAST(1 as float) / CAST(b.odds AS float))
											WHEN b.odds >=0 THEN (1 + b.odds) 
										END
									WHEN OddsType = 5 THEN --american odds to decimal
										CASE
											WHEN (b.odds * 100) < 0 THEN (1- CAST (1 AS float)/ CAST (b.odds AS float))
											WHEN (b.odds * 100) % 2 = 0 THEN 2
											WHEN (b.odds * 100) > 0 THEN (1 + b.odds) 
										END 
									END
							ELSE b.Odds END odds2,
					b.status,
					b.stake,
					(b.winlost-actual_stake) winlost,
					- (b.winlost-b.actual_stake) AS LicenseeWL,
					b.comm,
					b.playercomm,
					b.transdate,
					b.winlostdate,
					b.betteam,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.matchid,
					b.statusID,
					m.betstatus,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					b.OddsType,
					b.betid,
					b.currency,
					b.refno,
					m.ShowTime,
					b.betcheck,
					ISNULL(b.transdesc, '''''''') AS transdesc,
					ISNULL(b.betdaqid, -1) AS BetdaqId,
					ISNULL(b.ExtraInfo, '''''''') AS ExtraInfo,
					CASE
						WHEN b.ExtraInfo LIKE ''''%p25%'''' THEN
							ISNULL(CAST((''''<xml>'''' + b.ExtraInfo + ''''</xml>'''') AS XML).value(''''data(/xml/p25/@s)[1]'''',''''MONEY''''), 0)
						ELSE 0
					END AS OriginalStake,
					CASE
						WHEN b.stake <> 0 THEN -1
						ELSE 0
					END AS OriginalBetType,
					ISNULL(b.WalletType, 0) AS WalletType,
					ISNULL(b.RefCode, 0) AS RefCode
				FROM bodb_archive.dbo.bettrans_bk b WITH (NOLOCK, INDEX=IX_CUSTID)
					INNER JOIN cte_match m ON b.matchid = m.matchid
				WHERE b.winlostdate between ''''' 
					+ CAST(@fromdate AS VARCHAR) + '''''' + ' AND ''''' + CAST(@TempToDate AS VARCHAR) + '''''
					AND (b.bettype < 31
						OR (b.bettype BETWEEN 121 AND 999)
						OR (b.bettype BETWEEN 1301 AND 1399))
					AND b.statusID IN (111,112,113,114,115)
					AND b.Custid =' + CAST(@custid AS VARCHAR) + '
					AND b.tpositiontaking <> 0
					AND (' + CAST(@MatchId AS VARCHAR) + '=0 OR m.matchid=' + CAST(@MatchId AS VARCHAR) + ')
				'')'

			SELECT @sql = @OPENQUERY + @TSQL

			INSERT INTO #Data
			EXEC (@sql)
		END
	END

	DELETE #Data
	WHERE odds2 < @Odds
		OR StatusID NOT IN ( SELECT * FROM @Status )

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode		BIGINT,
			TransId		BIGINT,
			Stake		MONEY,
			WinLost		MONEY,
			LicenseeWL	MONEY,
			Comm		MONEY,
			PlayerComm	MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(WinLost) AS WinLost,
			SUM(LicenseeWL) AS LicenseeWL,
			SUM(Comm) AS Comm,
			SUM(PlayerComm) AS PlayerComm
		FROM #Data
		WHERE RefCode <> 0
		GROUP BY RefCode
		HAVING COUNT(*) > 1

		IF EXISTS (SELECT 1 FROM @RefCodeTmp)
		BEGIN
			-- Update data for summmary ticket
			UPDATE b
			SET
				b.Stake = r.Stake,
				b.WinLost = r.WinLost,
				b.LicenseeWL = r.LicenseeWL,
				b.Comm = r.Comm,
				b.PlayerComm = r.PlayerComm,
				b.WalletType = 0
			FROM #Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE #Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE #Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE #Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	DECLARE @RowStart	INT,
		@RowEnd			INT,
		@TotalRow		INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	SELECT @FromDate =	CASE
							WHEN MIN(winlostdate) > @Today THEN @Today
							ELSE MIN(winlostdate)
						END
		,@Todate =	CASE
						WHEN MAX(winlostdate) > @Today THEN @Today
						ELSE MAX(winlostdate)
					END
	FROM #Data

	--CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)
	CREATE NONCLUSTERED INDEX IDX_CustID_Data ON #Data (custid)

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN ( SELECT DISTINCT Currency FROM #Data )

	SELECT @TotalRows = COUNT(1)
	FROM #Data

	SELECT A.*
	FROM (
		SELECT
			ROW_NUMBER() OVER (ORDER BY b.Status, b.transid) AS RowNum,
			b.*,
			SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
			-- USD
			b.Stake			* e.USD AS StakeUSD,
			b.WinLost		* e.USD AS WinLostUSD,
			b.LicenseeWL	* e.USD AS LicenseeWLUSD,
			b.Comm			* e.USD AS CommUSD,
			b.PlayerComm	* e.USD AS PlayerCommUSD,
			b.OriginalStake	* e.USD AS OriginalStakeUSD,
			-- EUR
			b.Stake			* e.EUR AS StakeEUR,
			b.WinLost		* e.EUR AS WinLostEUR,
			b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
			b.Comm			* e.EUR AS CommEUR,
			b.PlayerComm	* e.EUR AS PlayerCommEUR,
			b.OriginalStake	* e.EUR AS OriginalStakeEUR,
			-- GBP
			b.Stake			* e.GBP AS StakeGBP,
			b.WinLost		* e.GBP AS WinLostGBP,
			b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
			b.Comm			* e.GBP AS CommGBP,
			b.PlayerComm	* e.GBP AS PlayerCommGBP,
			b.OriginalStake	* e.GBP AS OriginalStakeGBP
		FROM #Data AS b
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
			INNER JOIN #TempExchange AS e
				ON e.ExchangeDate = CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today END
				AND e.exchangeid = b.Currency
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #TempExchange
	DROP TABLE #Data
END


GO
GRANT	VIEW DEFINITION	ON	Lrf_BetList_WinlostByLeague_Mem	TO	vnteam
GRANT	EXECUTE	ON	Lrf_BetList_WinlostByLeague_Mem	TO	bodbLicenseeNet
GO

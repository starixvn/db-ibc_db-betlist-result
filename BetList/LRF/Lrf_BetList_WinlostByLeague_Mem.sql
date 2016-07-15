USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_WinlostByLeague_Mem]    Script Date: 4/20/2015 12:14:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_WinlostByLeague_Mem]
	@CustId			INT,
	@Odds			MONEY			= 0,
	@LeagueId		INT,
	@MatchId		INT				= 0,
	@LicenseeId		INT,
	@UserId			INT,
	@CurrencyId		INT				= 0,
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

	Param's Explanation: 
		- @CustID : Customer Number
		- @Odds : decimals odds, default >=0
		- @LeagueID : LeagueID, Number
		- @LicenseeID :Licensee ID
		- @UserID	 : User ID who run this report
		- @CurrencyID : Filter Currency . defaul=0 (All)
		- @PageSize : Number rows of one fage, for faging
		- @PageIndex : Index of paging
		- @TotalRows : Number rows of output
		- @FromDate : time range
		- @ToDate :time range
		- @MoveBetsDay : that day we use bettrans14
		- @BalanceUpDay : that day we use bettrans_bk
		- @ShowWin : show only win bet ,default =1
		- @ShowLoss: show only loss bet,default =1
		- @ShowDraw : show only draw bet,default =1
*/

BEGIN
	SET NOCOUNT ON

	SELECT currencyID
		,LicenseeID
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @userID, 1) -- System is default=1 (LRF)
	WHERE @CurrencyID = 0
		OR (@CurrencyID <> 0 AND CurrencyID = @CurrencyID)

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT, EventType INT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID = 1 AND BetType NOT IN (901, 902, 903, 904)

	-------
	DECLARE @TempAg AS TABLE (custid INT)

	INSERT INTO @TempAg (custid)
	SELECT DISTINCT CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc
		INNER JOIN #currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID

	DECLARE @IFromdate DATETIME
	DECLARE @ITodate DATETIME
	DECLARE @TempBettype AS TABLE (bettype INT PRIMARY KEY)

	CREATE TABLE #Data (
		SportType		INT
		,Username		NVARCHAR(50)
		,CustId			INT
		,Bettype		INT
		,LeagueId		INT
		,TransId		BIGINT
		,MatchCode		VARCHAR(50)
		,HomeId			INT
		,AwayId			INT
		,Hdp1			SMALLMONEY
		,Hdp2			SMALLMONEY
		,Odds			MONEY
		,Odds2			MONEY
		,Status			NVARCHAR(50)
		,Stake			MONEY
		,WinLost		MONEY
		,LicenseeWL		MONEY
		,Comm			MONEY
		,PlayerComm		MONEY
		,TransDate		DATETIME
		,WinLostDate	DATETIME
		,BetTeam		VARCHAR(50)
		,LiveIndicator	INT
		,LiveHomeScore	SMALLINT
		,LiveAwayScore	SMALLINT
		,MatchId		INT
		,StatusId		INT
		,BetStatus		NVARCHAR(50)
		,IsNeutral		BIT
		,OddsType		INT
		,BetId			BIGINT
		,Currency		SMALLINT
		,RefNo			BIGINT
		,ShowTime		NVARCHAR(50) -- table - shoe - hand of Live Casino
		,BetCheck		NVARCHAR(50)
		,TransDesc		NVARCHAR(300)
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

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT m.sporttype
				,b.username
				,b.custid
				,b.bettype
				,m.leagueID
				,b.transid
				,m.matchcode
				,m.homeID
				,m.awayID
				,CONVERT(FLOAT, b.hdp1) AS hdp1
				,CONVERT(FLOAT, b.hdp2) AS hdp2
				,b.Odds
				,CASE 
					WHEN (
							b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							)
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
				END odds2
				,b.STATUS
				,b.stake
				,(b.winlost - actual_stake) winlost
				,0 AS LicenseeWL
				,b.comm
				,b.playercomm
				,b.transdate
				,b.winlostdate
				,b.betteam
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,b.matchid
				,b.statusID
				,m.betstatus
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,b.OddsType
				,b.betid
				,b.currency
				,b.refno
				,'' AS ShowTime
				,b.betcheck
				,ISNULL(b.transdesc, '') AS transdesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @LeagueID
				AND ((@CurrencyID = 0 AND currency IN (SELECT currencyId FROM #currency)) 
					OR (@CurrencyID <> 0 AND Currency = @CurrencyID))
				AND b.statusID IN ( SELECT * FROM @status )
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.custid = @CustID
				AND tpositiontaking = 0 --getBA
				AND (@matchid = 0 OR m.matchid = @matchid)
			ORDER BY b.STATUS
				,b.transid
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT m.sporttype
				,b.username
				,b.custid
				,b.bettype
				,m.leagueID
				,b.transid
				,m.matchcode
				,m.homeID
				,m.awayID
				,CONVERT(FLOAT, b.hdp1) AS hdp1
				,CONVERT(FLOAT, b.hdp2) AS hdp2
				,b.Odds
				,CASE 
					WHEN (
							b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							)
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
				END odds2
				,b.STATUS
				,b.stake
				,(b.winlost - actual_stake) AS WinLost
				,CASE 
					WHEN b.tpositiontaking <> 0 THEN - (b.winlost - b.actual_stake)
					ELSE 0
				END AS LicenseeWL
				,b.comm
				,b.playercomm
				,b.transdate
				,b.winlostdate
				,b.betteam
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,b.matchid
				,b.statusID
				,m.betstatus
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,b.oddstype
				,b.betid
				,b.currency
				,b.refno
				,'' AS ShowTime
				,b.betcheck
				,ISNULL(b.transdesc, '') AS transdesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @LeagueID
				AND ((@CurrencyID = 0 AND currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND Currency = @CurrencyID))
				AND b.statusID IN ( SELECT * FROM @status )
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.custid = @CustID
				AND tpositiontaking <> 0
				AND (@matchid = 0 OR m.matchid = @matchid)
			ORDER BY b.STATUS
				,b.transid
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
			SELECT m.sporttype
				,b.username
				,b.custid
				,b.bettype
				,m.leagueID
				,b.transid
				,m.matchcode
				,m.homeID
				,m.awayID
				,CONVERT(FLOAT, b.hdp1) AS hdp1
				,CONVERT(FLOAT, b.hdp2) AS hdp2
				,b.Odds
				,CASE 
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
				END odds2
				,b.status
				,b.stake
				,(b.winlost - actual_stake) AS WinLost
				,0 AS LicenseeWL
				,b.comm
				,b.playercomm
				,b.transdate
				,b.winlostdate
				,b.betteam
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,b.matchid
				,b.statusID
				,m.betstatus
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,b.oddstype
				,b.betid
				,b.currency
				,b.refno
				,CASE 
					WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime, '')
					ELSE ''
				END AS ShowTime
				,b.betcheck
				,ISNULL(b.transdesc, '') AS transdesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @leagueID
				AND ((@CurrencyID = 0 AND currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND Currency = @CurrencyID))
				AND b.statusID IN ( SELECT * FROM @status )
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.custid = @CustID
				AND b.tpositiontaking = 0
				AND (@matchid = 0 OR m.matchid = @matchid)
			ORDER BY b.status
				,b.transid
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT m.sporttype
				,b.username
				,b.custid
				,b.bettype
				,m.leagueID
				,b.transid
				,m.matchcode
				,m.homeID
				,m.awayID
				,CONVERT(FLOAT, b.hdp1) AS hdp1
				,CONVERT(FLOAT, b.hdp2) AS hdp2
				,b.Odds
				,CASE 
					WHEN (
							b.bettype IN (1, 2, 3, 7, 12, 8, 20)
							OR b.bettype BETWEEN 81 AND 88
							OR b.bettype BETWEEN 90 AND 120
							)
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
				END odds2
				,b.STATUS
				,b.stake
				,(b.winlost - actual_stake) AS WinLost
				,CASE 
					WHEN b.tpositiontaking <> 0 THEN - (b.winlost - b.actual_stake)
					ELSE 0
				END AS LicenseeWL
				,b.comm
				,b.playercomm
				,b.transdate
				,b.winlostdate
				,b.betteam
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,b.matchid
				,b.statusID
				,m.betstatus
				,ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
				,b.OddsType
				,b.betid
				,b.currency
				,b.refno
				,CASE 
					WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime, '')
					ELSE ''
				END AS ShowTime
				,b.betcheck
				,ISNULL(b.transdesc, '') AS transdesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @TempAg AS ta ON b.recommend = ta.custid
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
			WHERE m.leagueid = @leagueID
				AND ((@CurrencyID = 0 AND currency IN (SELECT currencyId FROM #currency))
					OR (@CurrencyID <> 0 AND Currency = @CurrencyID))
				AND b.statusID IN (SELECT * FROM @status)
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.custid = @CustID
				AND b.tpositiontaking <> 0
				AND (@matchid = 0 OR m.matchid = @matchid)
			ORDER BY b.STATUS
				,b.transid
		END
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @todate >= DATEADD(dd, - 1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, - 1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @todate

		DECLARE @sql NVARCHAR(MAX)
		DECLARE @OPENQUERY NVARCHAR(4000)
			,@TSQL NVARCHAR(4000)
			,@LinkedServer NVARCHAR(40)

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
					AND EventDate BETWEEN ''''' + CAST(@fromdate AS VARCHAR) + '''''' + ' AND ''''' + CAST(@todate AS VARCHAR) + ''''')

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
					ISNULL(b.transdesc, '''''''') AS transdesc
				FROM
					bodb_archive.dbo.bettrans_bk  b WITH (NOLOCK, INDEX=IX_CUSTID) 
					INNER JOIN cte_match m ON b.matchid=m.matchid
				WHERE b.winlostdate BETWEEN ''''' 
					+ CAST(@fromdate AS VARCHAR) + '''''' + ' AND ''''' + CAST(@TempToDate AS VARCHAR) + '''''
					AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399)) AND
					b.statusID IN (111,112,113,114,115)
					AND b.Custid =' + CAST(@custid AS VARCHAR) + '
					AND b.tpositiontaking = 0
					AND (' + CAST(@matchid AS VARCHAR) + '=0 OR m.matchid=' + CAST(@matchid AS VARCHAR) + ')
					'')'

			SELECT @sql = @OPENQUERY + @TSQL

			INSERT INTO #Data
			EXEC (@sql)
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
					CASE WHEN b.tpositiontaking <> 0 THEN - (b.winlost-b.actual_stake)
						ELSE 0 
					END AS LicenseeWL,
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
					ISNULL(b.transdesc, '''''''') AS transdesc
				FROM bodb_archive.dbo.bettrans_bk b WITH (NOLOCK, INDEX=IX_CUSTID)
					INNER JOIN cte_match m ON b.matchid = m.matchid
				WHERE b.winlostdate between ''''' 
					+ CAST(@fromdate AS VARCHAR) + '''''' + ' AND ''''' + CAST(@TempToDate AS VARCHAR) + '''''
					AND (b.bettype<31 OR (b.bettype BETWEEN 121 AND 999) OR (b.bettype BETWEEN 1301 AND 1399)) AND
					b.statusID IN (111,112,113,114,115)
					AND b.Custid =' + CAST(@custid AS VARCHAR) + '
					AND b.tpositiontaking<>0
					AND (' + CAST(@matchid AS VARCHAR) + '=0 OR m.matchid=' + CAST(@matchid AS VARCHAR) + ')
				'')'

			SELECT @sql = @OPENQUERY + @TSQL

			INSERT INTO #Data
			EXEC (@sql)
		END
	END

	DECLARE @RowStart INT
		,@RowEnd INT
		,@TotalRow INT

	SELECT @PageIndex = @PageIndex - 1
		,@RowStart = @PageSize * @PageIndex + 1
		,@RowEnd = @RowStart + @PageSize - 1

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
	WHERE odds2 >= @Odds
		AND StatusID IN ( SELECT * FROM @Status )

	SELECT A.*
	FROM (
		SELECT ROW_NUMBER() OVER (ORDER BY b.STATUS, b.transid) AS RowNum
			,b.*
			,SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName
			--USD 
			,Stake		* e.USD AS StakeUSD
			,WinLost	* e.USD AS WinLostUSD
			,LicenseeWL	* e.USD AS LicenseeWLUSD
			,Comm		* e.USD AS CommUSD
			,PlayerComm	* e.USD AS PlayerCommUSD
			,Stake		* e.EUR AS StakeEUR
			,WinLost	* e.EUR AS WinLostEUR
			,LicenseeWL	* e.EUR AS LicenseeWLEUR
			,Comm		* e.EUR AS CommEUR
			,PlayerComm	* e.EUR AS PlayerCommEUR
			,Stake		* e.GBP AS StakeGBP
			,WinLost	* e.GBP AS WinLostGBP
			,LicenseeWL	* e.GBP AS LicenseeWLGBP
			,Comm		* e.GBP AS CommGBP
			,PlayerComm	* e.GBP AS PlayerCommGBP
		FROM #Data AS b
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = (
					CASE 
						WHEN b.winlostdate <= @Today THEN b.winlostdate
						ELSE @Today
					END
					)
				AND e.exchangeid = b.currency
		WHERE b.odds2 >= @Odds
			AND b.StatusID IN ( SELECT * FROM @Status )
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #Currency
	DROP TABLE #TempExchange
	DROP TABLE #Data
END


GO
GRANT	VIEW DEFINITION	ON	Lrf_BetList_WinlostByLeague_Mem	TO	vnteam
GRANT	EXECUTE	ON	Lrf_BetList_WinlostByLeague_Mem	TO	bodbLicenseeNet
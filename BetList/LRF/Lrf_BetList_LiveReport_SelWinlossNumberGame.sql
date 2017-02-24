use bodb02
go
set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			VARCHAR(20)		= 'Transid DESC',
	@LiveIndicator	INT				= 1
AS

/*
	Created: Henry@20120119
	Task: Betlist Number Game
	DB: DB052.bodb02
	Original: [Lrf_BetList_SelWinlossNumberGame]
	Revisions:
		Get all Number Game ticket in a duration FromDate => ToDate
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120724@Jim: add player commision value 
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130403@Jim: fix bug page index and liveindicator value 
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: Support to view currency UUS
		- 20140520@Hannah: Sort betlist
		- 20140522@Hannah: fix bug Sort betlist
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150124@Winnie: add base currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY, sporttype from TINYINT to SMALLINT [Redmine: #48660]
		- 20170301@Kos: Support sub licensees [#Redmine: 71679]

	Param's Explanation:
		@Liveindicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TempAg (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

	DECLARE @TempFromDate DATETIME 
	DECLARE @TempToDate DATETIME
	DECLARE @TempCount INT
	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE TABLE #Data (
		SportType		SMALLINT,
		CustId			INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		TransId			BIGINT,
		BetId			BIGINT,
		Race			VARCHAR(50),
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		MOdds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Discount		MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(25),
		APositionTaking	SMALLMONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(30),
		BetStatus		VARCHAR(50),
		IsNeutral		BIT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		-- USD
		StakeUSD		MONEY,
		WinLostUSD		MONEY,
		LicenseeWLUSD	MONEY,
		CommUSD			MONEY,
		-- EUR
		StakeEUR		MONEY,
		WinLostEUR		MONEY,
		LicenseeWLEUR	MONEY,
		CommEUR			MONEY,
		-- GBP
		StakeGBP		MONEY,
		WinLostGBP		MONEY,
		LicenseeWLGBP	MONEY,
		CommGBP			MONEY
	)

	CREATE INDEX IX_Data on #Data (Winlostdate, Currency)

	DECLARE @sql NVARCHAR(2500)
	DECLARE @SortTemp VARCHAR(250)
	DECLARE @LicenseeWL VARCHAR(150)

	SET @LicenseeWL = '(-1 * (b.winlost - b.actual_stake))'

	DECLARE @Winlost VARCHAR(150)

	SET @Winlost = '(b.winlost-b.actual_stake)'

	IF @Sort LIKE '%USD%' OR @Sort LIKE '%EUR%' OR @Sort LIKE '%GBP%'
	BEGIN
		DECLARE @charindex INT

		SELECT @charindex = CHARINDEX( ' ', @Sort, 1)

		IF @Sort LIKE '%Winlost%'
		BEGIN
			SELECT @SortTemp = @Winlost + '*e.' + SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
		END
		ELSE IF @Sort LIKE '%LicenseeWL%'
		BEGIN
			SELECT @SortTemp = @LicenseeWL + '*e.' + SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
		END
		ELSE
		BEGIN
			SELECT @SortTemp = SUBSTRING(@Sort, 1, @charindex - 4) + '*e.' + SUBSTRING(@Sort, @charindex - 3,4) 
				+ SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
		END
	END
	ELSE
	BEGIN
		SET @SortTemp = @Sort
	END

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		 SELECT @sql =
			'SELECT TOP (' + CAST(@RowEnd AS VARCHAR(50)) + ')
				161,
				b.custid,
				b.username,
				b.bettype,
				b.transid,
				ISNULL(b.BetID,0),
				'''' AS race,
				m.matchcode,
				0,
				0,
				b.hdp1,
				b.hdp2,
				modds,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS winlost,
				(-1 * (b.winlost - b.actual_stake)) AS licenseeWL,
				comm , 
				playercomm,
				b.adiscount,
				b.transdate,
				b.betteam,
				b.apositiontaking,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				m.leagueID,
				b.matchid,
				b.IP,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				--USD
				stake*e.USD stakeUSD,
				' + @Winlost + '*e.USD winlostUSD,
				' + @LicenseeWL + '*e.USD LicenseeWLUSD,
 				comm*e.USD commUSD,
				--EUR
				stake*e.EUR stakeEUR,
				' + @Winlost + '*e.EUR winlostEUR,
				' + @LicenseeWL + '*e.EUR LicenseeWLEUR,
				comm*e.EUR commEUR,
				--GBP
				stake*e.GBP stakeGBP,
				' + @Winlost + '*e.GBP winlostGBP,
				' + @LicenseeWL + '*e.GBP LicenseeWLGBP,
				comm*e.GBP commGBP
			FROM
				dbo.bettrans14 b WITH (NOLOCK,INDEX(bettrans143))
				INNER JOIN #TempAg t ON b.recommend = t.custid
				INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #TempExchange e ON b.currency = e.exchangeID AND b.winlostdate = e.exchangeDate
			WHERE
				b.bettype BETWEEN 81 AND 120 AND
				b.Winlostdate BETWEEN ''' + CAST(@FromDate AS VARCHAR(50)) + ''' AND ''' + CAST(@TempToDate AS VARCHAR(50)) + ''' AND
				b.statusID IN (111,112,113) AND
				((' + CAST(@Liveindicator AS VARCHAR(2)) + ' = 0 and b.liveindicator = 0)
				OR (' + CAST(@Liveindicator AS VARCHAR(2)) + ' = 1 and b.liveindicator = 1)
				OR (' + CAST(@Liveindicator AS VARCHAR(2)) + ' = 2))
			ORDER BY '+ @SortTemp 

		INSERT INTO #Data
			(sporttype,Custid,username,bettype,transid,BetID,race,matchcode,homeID,awayID,hdp1,
			hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,playercomm,discount ,
			transdate,betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,
			leagueID,matchid,IP,betstatus,isNeutral,winlostdate,currency,
			stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,stakeEUR,winlostEUR,LicenseeWLEUR,commEUR,
			stakeGBP,winlostGBP,LicenseeWLGBP,commGBP)
		EXEC (@sql)

		DELETE FROM #Data
		WHERE Currency NOT IN (SELECT DISTINCT Currency FROM #TempAg)
	END

	SELECT @TempCount = COUNT(1)
	FROM #Data

	IF @Todate > @MoveBetsDay AND @TempCount < @RowEnd
	BEGIN
		IF @FromDate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		SET @sql = 
			'SELECT TOP ('+CAST(@RowEnd AS VARCHAR(50))+') 
				161,
				b.custid,
				b.username,
				b.bettype,
				b.transid,
				ISNULL(b.BetID,0),
				'''' AS race,
				m.matchcode,
				0,
				0,
				b.hdp1,
				b.hdp2,
				modds,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS winlost,
				(-1 * (b.winlost - b.actual_stake)) AS licenseeWL,
				comm,
				playercomm,
				b.adiscount,
				b.transdate,
				b.betteam,
				b.apositiontaking,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				m.leagueID,
				b.matchid,
				b.IP,
  				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				--USD
				stake*e.USD stakeUSD,
				'+@Winlost+'*e.USD winlostUSD,
				'+@LicenseeWL+'*e.USD LicenseeWLUSD,
 				comm*e.USD commUSD,
				--EUR
				stake*e.EUR stakeEUR,
				'+@Winlost+'*e.EUR winlostEUR,
				'+@LicenseeWL+'*e.EUR LicenseeWLEUR,
				comm*e.EUR commEUR,
				--GBP
				stake*e.GBP stakeGBP,
				'+@Winlost+'*e.GBP winlostGBP,
				'+@LicenseeWL+'*e.GBP LicenseeWLGBP,
				comm*e.GBP commGBP
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #TempAg t ON b.recommend = t.custid
				INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #TempExchange e ON b.currency = e.exchangeID AND b.winlostdate = e.exchangeDate
			WHERE
				b.bettype BETWEEN 81 AND 120 AND
				b.Winlostdate BETWEEN ''' + CAST(@TempFromDate AS VARCHAR(50)) + ''' AND ''' + CAST(@ToDate AS VARCHAR(50)) + ''' AND
				b.statusID IN (111,112,113) AND
				((' + CAST(@Liveindicator AS VARCHAR(2)) + ' = 0 and b.liveindicator = 0)
				OR (' + CAST(@Liveindicator AS VARCHAR(2)) + ' = 1 and b.liveindicator = 1)
				OR (' + CAST(@Liveindicator AS VARCHAR(2)) + ' = 2))	
				ORDER BY '+ @SortTemp
	 
		INSERT INTO #Data
			(sporttype,Custid,username,bettype,transid,BetID,race,matchcode,homeID,awayID,hdp1,
			hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,playercomm,discount,
			transdate,betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,
			leagueID,matchid,IP,betstatus,isNeutral,winlostdate,currency,
			stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,stakeEUR,winlostEUR,LicenseeWLEUR,commEUR,stakeGBP,winlostGBP,LicenseeWLGBP,commGBP)
		EXEC (@sql)

		DELETE FROM #Data
		WHERE Currency NOT IN (SELECT DISTINCT Currency FROM #TempAg)
	END

	CREATE NONCLUSTERED INDEX IDX_Index_data ON #Data(Currency)

	SELECT @sql = 
		'SELECT A.* 
		FROM
		(
			SELECT
				ROW_NUMBER() over(ORDER BY ' + @Sort + ' ) AS RowNum,
				b.sporttype,b.Custid,b.username,b.bettype,b.transid,b.BetID,b.race,b.matchcode,b.homeID,b.awayID,b.hdp1,
				b.hdp2,b.Modds,b.odds,b.status,b.stake,b.winlost,b.licenseeWL,b.comm,b.playercomm,b.discount,
				b.transdate,b.betteam,b.apositiontaking,b.liveindicator,b.livehomescore,b.liveawayscore,
				b.leagueID,b.matchid,b.IP,b.betstatus,b.isNeutral,b.winlostdate,b.currency,
				SUBSTRING(c.username2, CHARINDEX(''$'',c.username2)+1, len(c.username2)-CHARINDEX(''$'',c.username2)) AS nickname,
				-- USD
				b.stakeUSD,
				b.winlostUSD,
				b.LicenseeWLUSD,
				b.commUSD,
				-- EUR
				b.stakeEUR,
				b.winlostEUR,
				b.LicenseeWLEUR,
				b.commEUR,
				-- GBP
				b.stakeGBP,
				b.winlostGBP,
				b.LicenseeWLGBP,
				b.commGBP
			FROM #Data b
				INNER JOIN dbo.Customer c (NOLOCK) ON b.custid = c.custid
		) A WHERE A.RowNum BETWEEN ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+' ORDER BY A.RowNum'

	EXEC (@sql)

	DROP TABLE #Data
	DROP TABLE #TempExchange
	DROP TABLE #TempAg
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossNumberGame] TO [vnteam] 
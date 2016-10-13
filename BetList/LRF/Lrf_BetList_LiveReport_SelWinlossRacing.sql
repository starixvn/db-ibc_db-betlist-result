ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossRacing]
	@LicenseeId			INT,
	@UserId				INT,
	@CurrencyId			INT				= 0,
	@SportType			INT				= 151,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME ,
	@SumWL				MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumWLUSD			MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumWLEUR			MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumWLGBP			MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT, 
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				VARCHAR(20)		= 'Transid DESC'
AS

/*
	Created: Henry@20120111
	Task: Betlist HR for Live Report
	DB: DBEXT.bodb02
	Original: [Lrf_BetList_SelWinlossHRFull]
	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code 
		- 20120706@Henry: fix bug due to missing insert playerdiscount
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: Support to view currency UUS 
		- 20140520@Hannah: Sort betlist
		- 20140522@Hannah: fix bug Sort betlist
		- 20141111@Winnie: Change from LicenseeCust to f_SelLicenseeCust
		- 20150126@Winnie: Add base currency GBP
		- 20150414@Winnie: Apply sporttype bettype matrix
		- 20150511@Jim: use table #SportBettype instead of @SportBettype
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY, sporttype from TINYINT to SMALLINT [Redmine: #48660]
		- 20161004@Kos: Add product bet type range for sub tickets [Redmine: #65045]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	CREATE TABLE #SportBettype (ProductID INT, Bettype INT, EventType INT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (2, 0, 0, 2, '', '', @IsTest)

	CREATE TABLE #TempAg (custid INT)
	DECLARE @TempFromDate DATETIME
	DECLARE @TempToDate DATETIME
	DECLARE @TempCount INT
	DECLARE @RowStart INT, @RowEnd INT
	DECLARE @DataSum AS TABLE (
		SUMWL			MONEY,
		SUMLicenseeWL	MONEY,
		Winlostdate		DATETIME,
		Currency		INT)

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE TABLE #Data (
		SportType		SMALLINT,
		CustId			INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		TransId			BIGINT PRIMARY KEY,
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
		Discount		MONEY,
		PlayerDiscount	MONEY,
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
		PlayerComm		MONEY,
		Actual_Stake	MONEY,
		AWinLost		MONEY,
		-- USD
		StakeUSD		MONEY,
		WinLostUSD		MONEY,
		LicenseeWLUSD	MONEY,
		CommUSD			MONEY,
		PlayerCommUSD	MONEY,
		-- EUR
		StakeEUR		MONEY,
		WinLostEUR		MONEY,
		LicenseeWLEUR	MONEY,
		CommEUR			MONEY,
		PlayerCommEUR	MONEY,
		-- GBP
		StakeGBP		MONEY,
		WinLostGBP		MONEY,
		LicenseeWLGBP	MONEY,
		CommGBP			MONEY,
		PlayerCommGBP	MONEY
	)

	SELECT currencyID,
		LicenseeID
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)
	WHERE @CurrencyID = 0
		OR (@CurrencyID <> 0 AND CurrencyID = @CurrencyID)

	INSERT INTO #TempAg (CustId)
	SELECT DISTINCT lc.CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc
		INNER JOIN #Currency AS c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	--------------------------------------------------------

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)

	DECLARE @sql NVARCHAR(2500)
	DECLARE @SortTemp VARCHAR(250)
	DECLARE @Winlost VARCHAR(150)

	SET @Winlost = '(b.winlost-b.actual_stake)'

	DECLARE @LicenseeWL VARCHAR(150) 
	SET @LicenseeWL = 'b.awinlost'

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
			SELECT @SortTemp = SUBSTRING(@Sort, 1, @charindex - 4) + '*e.' + SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
		END
	END
	ELSE
	BEGIN
		SET @SortTemp = @Sort
	END
	--------------------------------------------------------  
	IF @Fromdate <= @MoveBetsDay
	BEGIN  
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		--INSERT INTO #Data 
		SELECT @sql = 
			'SELECT TOP (' + CAST(@RowEnd AS VARCHAR(50)) + ')
				' + CAST(@SportType AS VARCHAR(15)) + ',
				b.custid,
				b.username,
				b.bettype,
				b.transid,
				m.groupmatch AS race,
				m.matchcode,
				m.teamID,
				0,
				b.hdp1,
				b.hdp2,
				modds,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-b.actual_stake) AS winlost,
				b.awinlost AS licenseeWL,
				b.comm,
				b.adiscount AS discount,
				b.playerdiscount,
				b.transdate,
				'''',
				b.apositiontaking,
				0,
				b.livehomescore,
				b.liveawayscore,
				m.leagueID,
				b.matchid,
				b.IP,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				b.playercomm,
				b.actual_stake,
				b.awinlost,
				--USD
				stake*e.USD stakeUSD,
 				(b.winlost-b.actual_stake)*e.USD winlostUSD,
				b.awinlost*e.USD LicenseeWLUSD,
				comm*e.USD commUSD,
				(b.playercomm * e.USD) AS playercommUSD,
				--EUR
				stake*e.EUR stakeEUR,
				(b.winlost-b.actual_stake)*e.EUR winlostEUR,
				b.awinlost*e.EUR LicenseeWLEUR,
				comm*e.EUR commEUR,
				(b.playercomm * e.EUR) AS playercommEUR,
				--GBP
				stake*e.GBP stakeGBP,
				(b.winlost-b.actual_stake)*e.GBP winlostGBP,
				b.awinlost*e.GBP LicenseeWLGBP,
				comm*e.GBP commGBP,
				(b.playercomm * e.GBP) AS playercommGBP
			FROM bettrans14 b WITH (NOLOCK,INDEX=bettrans143)
				INNER JOIN #TempAg t ON b.recommend = t.custid
				INNER JOIN outright14 m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN League l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN #TempExchange e ON b.currency = e.exchangeID AND b.winlostdate = e.exchangeDate
				INNER JOIN #SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.Winlostdate BETWEEN ''' + CAST(@FromDate AS VARCHAR(50)) + ''' AND ''' + CAST(@TempToDate AS VARCHAR(50)) + ''' AND
				l.SportType= '+CAST(@SportType AS VARCHAR(15))+' AND
				b.statusID IN (111,112,113)
			ORDER  BY '+ @SortTemp 

		INSERT INTO #Data
			(sporttype,Custid,username,bettype,transid,race,matchcode,homeID,awayID,hdp1,
			hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,discount ,playerdiscount,
			transdate,betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,  
			leagueID,matchid,IP,betstatus,isNeutral,winlostdate,currency,playercomm,b.actual_stake,b.awinlost,
			stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,playercommUSD,stakeEUR,winlostEUR,LicenseeWLEUR,commEUR,playercommEUR
			,stakeGBP,winlostGBP,LicenseeWLGBP,commGBP,playercommGBP)
		EXEC (@sql)

		IF @CurrencyID <> 0
			DELETE FROM #Data
			WHERE currency != @CurrencyID

		IF @CurrencyID = 0
			DELETE FROM #Data
			WHERE currency NOT IN (SELECT CurrencyId FROM #Currency)
	 
		INSERT INTO @DataSum
		SELECT
			SUM(b.winlost - actual_stake + playercomm),
			SUM(b.awinlost + comm),
			b.winlostdate,
			b.currency
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK,INDEX=bettrans143)
			INNER JOIN #TempAg AS t ON b.recommend = t.custid
			INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		WHERE
			b.Winlostdate BETWEEN @FromDate AND @TempToDate
			AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND b.currency = @CurrencyID))
			AND l.SportType= @SportType
			AND b.bettype BETWEEN 31 AND 33
			AND b.statusID IN (111,112,113)
		GROUP BY b.Winlostdate,
			b.Currency
	END

	SELECT @TempCount = COUNT(1) FROM #Data

	IF @Todate > @MoveBetsDay AND @TempCount < @RowEnd
	BEGIN
		IF @FromDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		--INSERT INTO #Data 
		SELECT @sql =
			'SELECT TOP (' + CAST(@RowEnd AS VARCHAR(50)) + ')
				' + CAST(@SportType AS VARCHAR(15)) + ',
				b.custid,
				b.username,
				b.bettype,
				b.transid,
				m.groupmatch AS race,
				m.matchcode,
				m.teamID,
				0,
				b.hdp1,
				b.hdp2,
				modds,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS winlost,
				b.awinlost AS licenseeWL,
				b.comm,
				b.adiscount,
				b.playerdiscount AS playerdiscount,
				b.transdate,
				'''',
				b.apositiontaking,
				0,
				b.livehomescore,
				b.liveawayscore,
				m.leagueID,
				b.matchid,
				b.IP,
  				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				b.playercomm,
				b.actual_stake,
				b.awinlost,
				--USD
				stake*e.USD stakeUSD,
 				(b.winlost-b.actual_stake)*e.USD winlostUSD,
				b.awinlost*e.USD LicenseeWLUSD,
				comm*e.USD commUSD,
				(b.playercomm * e.USD) AS playercommUSD,
				--EUR
				stake*e.EUR stakeEUR,
				(b.winlost-b.actual_stake)*e.EUR winlostEUR,
				b.awinlost*e.EUR LicenseeWLEUR,
				comm*e.EUR commEUR,
				(b.playercomm * e.EUR) AS playercommEUR,
				--GBP
				stake*e.GBP stakeGBP,
				(b.winlost-b.actual_stake)*e.GBP winlostGBP,
				b.awinlost*e.GBP LicenseeWLGBP,
				comm*e.GBP commGBP,
				(b.playercomm * e.GBP) AS playercommGBP
			FROM
				dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #TempAg t ON b.recommend = t.custid
				INNER JOIN dbo.outright m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN #TempExchange e ON b.currency = e.exchangeID AND b.winlostdate = e.exchangeDate
				INNER JOIN #SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.Winlostdate BETWEEN ''' + CAST(@TempFromDate AS VARCHAR(50)) + ''' AND ''' + CAST(@ToDate AS VARCHAR(50)) + ''' AND
				l.SportType= ' + CAST(@SportType AS VARCHAR(15)) + ' AND
				b.statusID IN (111,112,113)
			ORDER BY '+ @SortTemp

		INSERT INTO #Data
			(sporttype,Custid,username,bettype,transid,race,matchcode,homeID,awayID,hdp1 ,  
			hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,discount ,playerdiscount,
			transdate,betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,  
			leagueID,matchid,IP,betstatus,isNeutral,winlostdate,currency,playercomm,b.actual_stake,b.awinlost,
			stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,playercommUSD,stakeEUR,winlostEUR,LicenseeWLEUR,commEUR,playercommEUR
			,stakeGBP,winlostGBP,LicenseeWLGBP,commGBP,playercommGBP)
		EXEC (@sql)

		IF @CurrencyID <> 0
			DELETE FROM #Data
			WHERE currency != @CurrencyID

		IF @CurrencyID = 0
			DELETE FROM #Data
			WHERE currency NOT IN (SELECT CurrencyId FROM #Currency)

		INSERT INTO @DataSum 
		SELECT
			SUM(b.winlost-actual_stake),
			SUM(b.awinlost),
			b.Winlostdate,
			b.Currency
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS t ON b.recommend = t.custid
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND ((@CurrencyID = 0 AND currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND Currency = @CurrencyID))
			AND l.SportType = @SportType
			AND b.bettype BETWEEN 31 AND 33
			AND b.statusID IN (111, 112, 113)
		GROUP BY b.winlostdate,
			b.Currency
	END

	CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

	SET @sql = 
		'SELECT A.*
		FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY ' + @SortTemp + ' ) AS RowNum,
				b.sporttype,
				b.Custid,
				b.username,
				b.bettype,
				b.transid,
				b.race,
				b.matchcode,
				b.homeID,
				b.awayID,
				b.hdp1,
				b.hdp2,
				b.Modds,
				b.odds,
				b.status,
				b.stake,
				b.winlost,
				b.licenseeWL,
				b.comm,
				b.discount,
				b.playerdiscount,
				b.transdate,
				b.betteam,
				b.apositiontaking,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.leagueID,
				b.matchid,
				b.IP,
				b.betstatus,
				b.isNeutral,
				b.winlostdate,
				b.currency,
				b.playercomm,
				SUBSTRING(c.username2, CHARINDEX(''$'',c.username2)+1, len(c.username2)-CHARINDEX(''$'',c.username2)) AS nickname,   		
				--USD
				--b.stakeUSD,b.winlostUSD,b.LicenseeWLUSD,b.commUSD,b.playercommUSD,
				--EUR
				--b.stakeEUR,b.winlostEUR,b.LicenseeWLEUR,b.commEUR,b.playercommEUR,
				--GBP
				--b.stakeGBP,b.winlostGBP,b.LicenseeWLGBP,b.commGBP,b.playercommGBP
				b.stake*e.USD stakeUSD,
				'+@winlost+'*e.USD winlostUSD,
				'+@LicenseeWL+'*e.USD LicenseeWLUSD,
				b.comm*e.USD commUSD,
				(b.playercomm * e.USD) AS playercommUSD,
				--EUR
				b.stake*e.EUR stakeEUR,
				'+@winlost+'*e.EUR winlostEUR,
				'+@LicenseeWL+'*e.EUR LicenseeWLEUR,
				b.comm*e.EUR commEUR,
				(b.playercomm * e.EUR) AS playercommEUR,	
					--GBP
				b.stake*e.GBP stakeGBP,
				'+@winlost+'*e.GBP winlostGBP,
				'+@LicenseeWL+'*e.GBP LicenseeWLGBP,
				b.comm*e.GBP commGBP,
				(b.playercomm * e.GBP) AS playercommGBP
			FROM #Data AS b
				INNER JOIN Customer AS c (NOLOCK) ON b.custid = c.custid
				INNER JOIN #TempExchange AS e ON b.currency = e.exchangeID AND b.winlostdate = e.exchangeDate
		) A WHERE A.RowNum between ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+' ORDER BY A.RowNum'

	EXEC (@sql)

	-- Get sub tickets for bet type 33
	DECLARE @Bettransm TABLE (
		RefNo			BIGINT,
		FinalOdds		MONEY,
		Odds			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT
	)

	IF EXISTS (SELECT 1 FROM #Data)
	BEGIN
		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO @Bettransm
			SELECT
				bm.refno,
				bm.finalodds,
				bm.odds,
				bm.status,
				bm.apositiontaking,
				bm.bettype
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN #Data AS b ON bm.refno = b.transid AND bm.custid = b.CustId
				INNER JOIN #SportBettype AS sbt ON sbt.Bettype = bm.bettype
		END
	
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @Bettransm
			SELECT
				bm.refno,
				bm.finalodds,
				bm.odds,
				bm.status,
				bm.apositiontaking,
				bm.bettype
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN #Data AS b ON bm.refno = b.transid AND bm.custid = b.CustId
				INNER JOIN #SportBettype AS sbt ON sbt.Bettype = bm.bettype
		END
	END

	SELECT * FROM @Bettransm
	ORDER BY RefNo, Bettype

	/*
	--SUM table : 2012-07-29@Jim added :
		SELECT 	@SUMWL=SUM(SUMWL),
				@SUMLicenseeWL=SUM(SUMLicenseeWL),
				@SUMWLUSD=SUM(SUMWL*e.USD),
				@SUMLicenseeWLUSD=SUM(SUMLicenseeWL*e.USD),
				@SUMWLEUR=SUM(SUMWL*e.EUR),
				@SUMLicenseeWLEUR=SUM(SUMLicenseeWL*e.EUR)
		FROM @DataSum b
		INNER JOIN  #TempExchange e ON b.currency=e.exchangeID AND b.winlostdate=e.exchangeDate
	
	--SELECT 	@SUMWL,@SUMLicenseeWL,@SUMWLUSD,@SUMLicenseeWLUSD,@SUMWLEUR,@SUMLicenseeWLEUR
	*/
	DROP TABLE #Data
	DROP TABLE #TempExchange 
	DROP TABLE #TempAg
	DROP TABLE #Currency 
	DROP TABLE #SportBettype
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossRacing] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossRacing] TO [vnteam] 
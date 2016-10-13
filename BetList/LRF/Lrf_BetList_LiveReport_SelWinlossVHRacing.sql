ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossVHRacing]
	@LicenseeId			INT,
	@UserId				INT,
	@CurrencyId			INT				= 0,
	@SportType			INT				= 181,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@SUMWL				MONEY			= 0 OUTPUT,
	@SUMLicenseeWL		MONEY			= 0 OUTPUT,
	@SUMWLUSD			MONEY			= 0 OUTPUT,
	@SUMLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SUMWLEUR			MONEY			= 0 OUTPUT,
	@SUMLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SUMWLGBP			MONEY			= 0 OUTPUT,
	@SUMLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				VARCHAR(20)		= 'Transid DESC'
AS

/*
	Created: Jim@20130912
	Task: Betlist VHR for Live Report
	DB: DBEXT.bodb02
	Original: 
	Revisions:
		- 20140520@Hannah: Sort betlist
		- 20140522@Hannah: fix bug Sort betlist
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
		- 20150126@Winnie: Add base currency GBP 
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
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
	FROM dbo.f_SportBettypeMatrix_Sel (5, 0, 0, 2, '', '', @IsTest)

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
		RefNo			BIGINT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		TransId			BIGINT PRIMARY KEY,
		Race			VARCHAR(50),
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		Modds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		Discount		MONEY,
		PlayerDiscount	MONEY,
		TransDate		DATETIME,
		Betteam			NVARCHAR(25),
		APositiontaking	SMALLMONEY,
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
		ShowTime		DATETIME,
		--USD
		StakeUSD		MONEY,
		WinLostUSD		MONEY,
		LicenseeWLUSD	MONEY,
		CommUSD			MONEY,
		PlayerCommUSD	MONEY,
		--EUR
		StakeEUR		MONEY,
		WinLostEUR		MONEY,
		LicenseeWLEUR	MONEY,
		CommEUR			MONEY,
		PlayerCommEUR	MONEY,
		--GBP
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

	INSERT INTO #TempAg ( CustId)
	SELECT DISTINCT lc.CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc
		INNER JOIN #Currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID

	--------------------------------------------------------  
	DECLARE @sql NVARCHAR(2500)
	DECLARE @SortTemp VARCHAR(250) 
	DECLARE @LicenseeWL VARCHAR(150) 
	DECLARE @Winlost VARCHAR(150) 

	SET @LicenseeWL = '(-(b.winlost-b.actual_stake))'
	SET @Winlost = '(b.winlost-b.actual_stake)'

	IF @Sort LIKE '%USD%' OR @Sort LIKE '%EUR%' OR @Sort LIKE '%GBP%'
	BEGIN
		DECLARE @charindex INT

		SELECT @charindex = CHARINDEX( ' ', @Sort, 1)

		IF @Sort LIKE '%Winlost%'
		BEGIN
			SELECT @SortTemp = @Winlost + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
		END
		ELSE IF @Sort LIKE '%LicenseeWL%'
		BEGIN
			SELECT @SortTemp = @LicenseeWL + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
		END
		ELSE
		BEGIN
			SELECT @SortTemp = SUBSTRING (@Sort, 1, @charindex - 4) + '*e.'+SUBSTRING(@Sort, @charindex - 3,4) + SUBSTRING(@Sort, @charindex + 1, LEN(@Sort))
		END
	END
	ELSE
	BEGIN
		SET @SortTemp = @Sort
	END

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET  @TempToDate = @ToDate

		--INSERT INTO #Data 
		SELECT @sql =
			'SELECT TOP ('+CAST(@RowEnd AS VARCHAR(50))+')
				'+CAST(@SportType AS VARCHAR(15))+',  
				b.custid,
				b.refno,
				b.username,
				b.bettype,
				b.transid,
				b.oddsid AS race,
				CONVERT(VARCHAR(50),o.RacerNum) matchcode,  
				o.RacerID teamID,
				0,
				b.hdp1,
				b.hdp2,
				modds,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake) AS winlost,  
				(-(b.winlost-actual_stake)) AS licenseeWL,
				b.comm AS Comm, 
				b.adiscount AS discount,
				b.playerdiscount,
				b.transdate,  
				'''',  
				b.apositiontaking,
				0,
				b.livehomescore,
				b.liveawayscore,
				r.leagueID,
				o.EventID matchid,
				b.IP,
				NULL,  
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				b.playercomm,
				r.EventTime,
				--USD
				stake*e.USD stakeUSD,
				'+@winlost+'*e.USD winlostUSD,
				'+@LicenseeWL+'*e.USD LicenseeWLUSD,
				comm*e.USD commUSD,
				(b.playercomm * e.USD) AS playercommUSD,
				--EUR
				stake*e.EUR stakeEUR,
				'+@winlost+'*e.EUR winlostEUR,
				'+@LicenseeWL+'*e.EUR LicenseeWLEUR,
				comm*e.EUR commEUR,
				(b.playercomm * e.EUR) AS playercommEUR,
				--GBP
				stake*e.GBP stakeGBP,
				'+@winlost+'*e.GBP winlostGBP,
				'+@LicenseeWL+'*e.GBP LicenseeWLGBP,
				comm*e.GBP commGBP,
				(b.playercomm * e.GBP) AS playercommGBP
			FROM  
				bettrans14 b WITH (NOLOCK)
				INNER JOIN #TempAg t  ON b.recommend = t.custid
				INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN #TempExchange e ON b.currency = e.exchangeID AND b.winlostdate = e.exchangeDate
			WHERE
				b.Winlostdate BETWEEN '''+CAST(@FromDate AS VARCHAR(50))+''' AND '''+CAST(@TempToDate AS VARCHAR(50))+''' AND 	  
				r.SportType= '+CAST(@SportType AS VARCHAR(15))+' AND
				b.bettype IN (1231,1232,1233,1237,1238) AND 
				b.statusID IN (111,112,113)
			ORDER BY '+ @SortTemp 

		INSERT INTO #Data
			(sporttype,Custid,refno,username,bettype,transid,race,matchcode,homeID,awayID,hdp1,  
			hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,discount,playerdiscount,transdate,  
			betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,leagueID,matchid,   
			IP,betstatus,isNeutral,winlostdate,currency,playercomm,showtime,
			stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,playercommUSD,
			stakeEUR,winlostEUR,LicenseeWLEUR,commEUR,playercommEUR,
			stakeGBP,winlostGBP,LicenseeWLGBP,commGBP,playercommGBP)
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
			b.Winlostdate,
			b.Currency
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS t ON b.recommend = t.custid
			INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE
			b.Winlostdate BETWEEN @FromDate AND @TempToDate
			AND ((@CurrencyID = 0 AND currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND Currency = @CurrencyID))
			AND r.SportType= @SportType
			AND b.bettype IN (1231,1232,1233,1237,1238)
			AND b.statusID IN (111,112,113)
		GROUP BY b.Winlostdate,
			b.Currency
	END

	SELECT @TempCount = COUNT(1) FROM #Data

	IF @Todate > @MoveBetsDay  AND @TempCount < @RowEnd
	BEGIN
		IF @FromDate <= @MoveBetsDay 
			SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate
		
		--INSERT INTO #Data 
		SELECT @sql =
			'SELECT TOP ('+CAST(@RowEnd AS VARCHAR(50))+')
				'+CAST(@SportType AS VARCHAR(15))+',  
				b.custid,
				b.refno,
				b.username,  	  
				b.bettype,    	    
				b.transid,  
				b.oddsid AS race,  
				CONVERT(VARCHAR(50),o.RacerNum) matchcode,  
				o.RacerID teamID,  
				0,  
				b.hdp1,  
				b.hdp2,  
				modds,
				b.odds,  
				b.status,  
				b.stake,  
				(b.winlost-actual_stake) AS winlost,  
				(-(b.winlost-actual_stake)) AS licenseeWL,
				b.comm AS Comm, 
				b.adiscount AS discount,
				b.playerdiscount,
				b.transdate,  
				'''',  
				b.apositiontaking,
				0,
				b.livehomescore,
				b.liveawayscore,    
				r.leagueID,  
				o.EventID matchid,   
				b.IP,
				NULL,  
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				b.playercomm ,
				r.EventTime,
				--USD
				stake*e.USD stakeUSD,
				'+@winlost+'*e.USD winlostUSD,
				'+@LicenseeWL+'*e.USD LicenseeWLUSD,
				comm*e.USD commUSD,
				(b.playercomm * e.USD) AS playercommUSD,
				--EUR
				stake*e.EUR stakeEUR,
				'+@winlost+'*e.EUR winlostEUR,
				'+@LicenseeWL+'*e.EUR LicenseeWLEUR,
				comm*e.EUR commEUR,
				(b.playercomm * e.EUR) AS playercommEUR,
				--GBP
				stake*e.GBP stakeGBP,
				'+@winlost+'*e.GBP winlostGBP,
				'+@LicenseeWL+'*e.GBP LicenseeWLGBP,
				comm*e.GBP commGBP,
				(b.playercomm * e.GBP) AS playercommGBP
			FROM  
				bettrans b WITH (NOLOCK)
				INNER JOIN #TempAg t  ON b.recommend = t.custid
				INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN #TempExchange e ON b.currency = e.exchangeID AND b.winlostdate = e.exchangeDate
			WHERE
				b.Winlostdate BETWEEN '''+CAST(@TempFromDate AS VARCHAR(50))+''' AND '''+CAST(@ToDate AS VARCHAR(50))+''' AND 	  
				r.SportType= '+CAST(@SportType AS VARCHAR(15))+' AND
				b.bettype IN (1231,1232,1233,1237,1238) AND 
				b.statusID IN (111,112,113)
			ORDER  BY '+ @SortTemp 

		INSERT INTO #Data
			(sporttype,Custid,refno,username,bettype,transid,race,matchcode,homeID,awayID,hdp1,  
			hdp2,Modds,odds,status,stake,winlost,licenseeWL,comm,discount,playerdiscount,transdate,  
			betteam,apositiontaking,liveindicator,livehomescore,liveawayscore,leagueID,matchid,   
			IP,betstatus,isNeutral,winlostdate,currency,playercomm,showtime,
			stakeUSD,winlostUSD,LicenseeWLUSD,commUSD,playercommUSD,
			stakeEUR,winlostEUR,LicenseeWLEUR,commEUR,playercommEUR,
			stakeGBP,winlostGBP,LicenseeWLGBP,commGBP,playercommGBP)
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
			SUM(	b.awinlost),
			b.Winlostdate,
			b.Currency
		FROM
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #TempAg t  ON b.recommend = t.custid
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
		WHERE
			b.Winlostdate BETWEEN @TempFromDate AND @ToDate
			AND ((@CurrencyID = 0 AND currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND Currency = @CurrencyID))
			AND r.SportType= @SportType
			AND b.bettype IN (1231,1232,1233,1237,1238)
			AND b.statusID IN (111,112,113)
		GROUP BY b.winlostdate,
			b.Currency
	END

	CREATE NONCLUSTERED INDEX IDX_Index_Data ON #Data (Currency)

	SELECT @sql = 
		'SELECT A.* 
		FROM
		(
			SELECT  
					ROW_NUMBER() over(ORDER BY '+ @Sort+') AS RowNum,
					b.sporttype,b.Custid,b.refno,b.username,b.bettype,b.transid,b.race,b.matchcode,b.homeID,b.awayID,b.hdp1,  
					b.hdp2,b.Modds,b.odds,b.status,b.stake,b.winlost,b.licenseeWL,b.comm,b.discount,b.playerdiscount,b.transdate,  
					b.betteam,b.apositiontaking,b.liveindicator,b.livehomescore,b.liveawayscore,b.leagueID,b.matchid,   
					b.IP,b.betstatus,b.isNeutral,b.winlostdate,b.currency,b.playercomm,b.showtime,
					SUBSTRING(c.username2,  CHARINDEX(''$'',c.username2)+1, len(c.username2)-CHARINDEX(''$'',c.username2)) AS nickname,   		
					--USD
					b.stakeUSD,
					b.winlostUSD,
					b.LicenseeWLUSD,
					b.commUSD,
					b.playercommUSD,
					--EUR
					b.stakeEUR,
					b.winlostEUR,
					b.LicenseeWLEUR,
					b.commEUR,
					b.playercommEUR,
					--GBP
					b.stakeGBP,
					b.winlostGBP,
					b.LicenseeWLGBP,
					b.commGBP,
					b.playercommGBP
			FROM #Data b
				INNER JOIN Customer c (NOLOCK) ON b.custid = c.custid
		) A WHERE A.RowNum between ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+' ORDER BY A.RowNum'

	EXEC (@sql)

	-- Get sub tickets for bet type 1233
	DECLARE @Bettransm TABLE(
		RefNo			BIGINT,
		FinalOdds		MONEY,
		Odds			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT
	)

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
			INNER JOIN #Data AS b ON bm.refno = b.refno AND bm.custid = b.custid
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
			INNER JOIN #Data AS b ON bm.refno = b.refno AND bm.custid = b.custid
			INNER JOIN #SportBettype AS sbt ON sbt.Bettype = bm.bettype
	END

	SELECT * FROM @Bettransm
	ORDER BY RefNo, Bettype

	DROP TABLE #Data
	DROP TABLE #TempExchange
	DROP TABLE #TempAg
	DROP TABLE #Currency
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossVHRacing] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossVHRacing] TO [vnteam] 
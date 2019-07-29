/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Running]
	@AgentList			VARCHAR(MAX),
	@CustId				INT				= 0,
	@Username			VARCHAR(50)		= '',
	@BaseCurrency		VARCHAR(10),
	@ConvertToBaseCur	BIT				= 0,	-- Convert to base currency or not
	@StatusFilter		VARCHAR(10)		= '1,2,3',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				NVARCHAR(50)	= N'TransId ASC',
	@ProductList		VARCHAR(200)	= '',
	@ShowBA				BIT				= 0,	-- BA
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Running Bet List
	DB: DB042.bodb02
	Param's Explanation:
		- @StatusFilter:
			- 1: Running, Waiting
			- 2: Result Pending
			- 3: Under Settlement
			- 4: Pending

	Revisions:
		- 20180613@Kos: Created [#Redmine: 80941]
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
		- 20181121@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 107165]
		- 20190121@Kos: Betting Ticket Center phase 3a [Redmine: #103555]
					- Remove param @FromDate and @ToDate
		- 20190305@Kos: Add new param @StatusFilter, @ConvertToBaseCur [Redmine: #108717]
					- Remove param @CurrencyId
		- 20190411@Kos: Support search LIKE on username [Redmine: #111665]
		- 20190422@Kos: Enhance performance for searching too many members [Redmine: #112313]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]
		- 20190506@Kos: Result Pending for SettlementStatus = 5 [Redmine: #112886]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190627@Kos: Support PH AIO 4a [Redmine: #115448]
		- 20190730@Kos: Support new status Pending [#Redmine: 117729]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @HasError BIT = 0

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
		SET @HasError = 1
	END CATCH

	CREATE TABLE #Data (
		TransId				BIGINT,
		RefNo				BIGINT,
		BATransId			BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					NVARCHAR(15),
		BetFrom				NVARCHAR(1),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		ProductId			INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(64),
		TableID				TINYINT,
		Product				VARCHAR(30)
	)

	CREATE TABLE #PagingData (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		BATransId			BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					NVARCHAR(15),
		BetFrom				NVARCHAR(1),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		ProductId			INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(64),
		TableID				TINYINT,
		Product				VARCHAR(30)
	)

	DECLARE @Detail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	-- Get exchange rate
	CREATE TABLE #ExchangeRate (
		ExchangeId	INT,
		Rate		FLOAT
	)

	IF @HasError = 0
	BEGIN
		DECLARE @TempCust TABLE (CustId INT)

		IF @Username IS NOT NULL AND @Username <> ''
		BEGIN
			INSERT INTO @TempCust
			SELECT c.custid
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN @TempAg AS a ON c.recommend = a.CustId
			WHERE c.roleid = 1
				AND (c.username LIKE + '%' + @Username + '%'
					OR c.username2 LIKE + '%$%' + @Username + '%')
		END

		DECLARE @NumOfMem	INT = 0

		SELECT @NumOfMem = COUNT(1) FROM @TempCust

		IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username of number of searched member > 5000)
		BEGIN
			-- bettrans
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Currency,
				Recommend,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsId,
				OddsType,
				Odds,
				MOdds,
				OddsSpread,
				Stake,
				Actual_Stake,
				Status,
				SecAcceptFlag,
				CheckTime,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				BetdaqId,
				ExtraInfo,
				WalletType,
				RefCode,
				TableID)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.currency,
				b.recommend,
				b.bettype,
				ISNULL(b.BetId, 0) AS BetId,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddsid,
				b.oddstype,
				b.odds,
				b.modds,
				b.oddsspread,
				b.stake,
				b.actual_stake,
				b.status,
				b.SecAcceptFlag,
				b.checktime,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.betfrom,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.betdaqid,
				b.ExtraInfo,
				b.WalletType,
				ISNULL(b.RefCode, 0),
				1 AS TableID
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)
				INNER JOIN @TempAg AS a ON a.CustId = b.recommend
			WHERE b.statusID IN (0, 1)

			-- translog
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Currency,
				Recommend,
				BetType,
				Odds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				Ip,
				BetFrom,
				TransDesc,
				ProductId,
				Custom1,
				Custom2,
				Custom3,
				Gameid3rd,
				Tranid3rd,
				TableID
			)
			SELECT
				b.translogid AS TransId,
				b.translogid AS RefNo,
				b.custid,
				b.currency,
				b.recommend,
				b.gameID AS BetType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.transdate AS WinLostDate,
				b.LiveIndicator,
				b.ip,
				b.betfrom,
				b.transdesc,
				b.productID,
				b.custom1,
				b.custom2,
				b.custom3,
				b.GameId3rd,
				b.TranId3rd,
				2 AS TableID
			FROM dbo.translog AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)
				INNER JOIN @TempAg AS a ON a.CustId = b.recommend
			WHERE b.statusID IN (0, 1)
		END
		ELSE		-- Customer level
		BEGIN
			-- bettrans
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Currency,
				Recommend,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsId,
				OddsType,
				Odds,
				MOdds,
				OddsSpread,
				Stake,
				Actual_Stake,
				Status,
				SecAcceptFlag,
				CheckTime,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				BetdaqId,
				ExtraInfo,
				WalletType,
				RefCode,
				TableID)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.currency,
				b.recommend,
				b.bettype,
				ISNULL(b.BetId, 0) AS BetId,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddsid,
				b.oddstype,
				b.odds,
				b.modds,
				b.oddsspread,
				b.stake,
				b.actual_stake,
				b.status,
				b.SecAcceptFlag,
				b.checktime,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.betfrom,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.betdaqid,
				b.ExtraInfo,
				b.WalletType,
				ISNULL(b.RefCode, 0),
				1 AS TableID
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_custid)
				INNER JOIN @TempCust AS c ON b.custid = c.CustId
			WHERE b.statusID IN (0, 1)

			-- translog
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Currency,
				Recommend,
				BetType,
				Odds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				Ip,
				BetFrom,
				TransDesc,
				ProductId,
				Custom1,
				Custom2,
				Custom3,
				Gameid3rd,
				Tranid3rd,
				TableID
			)
			SELECT
				b.translogid AS TransId,
				b.translogid AS RefNo,
				b.custid,
				b.currency,
				b.recommend,
				b.gameID AS BetType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.transdate AS WinLostDate,
				b.LiveIndicator,
				b.ip,
				b.betfrom,
				b.transdesc,
				b.productID,
				b.custom1,
				b.custom2,
				b.custom3,
				b.GameId3rd,
				b.TranId3rd,
				2 AS TableID
			FROM dbo.translog AS b WITH (NOLOCK, INDEX = IX_betrunning_custid)
				INNER JOIN @TempCust AS c ON b.custid = c.CustId
			WHERE b.statusID IN (0, 1)
		END

		IF @Username IS NULL OR @Username = '' OR @NumOfMem <= 5000
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
		END
		ELSE
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE NOT EXISTS (SELECT 1 FROM @TempCust WHERE CustId = b.CustId)
				OR NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			DECLARE @ShowSB BIT = 0

			IF ',' + @ProductList + ',' LIKE '%,SB,%'
			BEGIN
				SET @ShowSB = 1
			END

			IF 1 IN (@ShowBA)
				AND ',' + @ProductList + ',' NOT LIKE '%,SB,%'
			BEGIN
				SET @ProductList = 'SB,' + @ProductList
			END

			DECLARE @IsTest BIT = 0

			SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

			-- Get Sport/Bettype info
			UPDATE b
			SET
				BATransId = ba.TransID,
				Product = CASE
							WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
							WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
							WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
							WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
							WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
							WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'			-- Betradar Virtual Sports
							WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
							WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
							ELSE 'Unknown'
						END
			FROM #Data AS b
				INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s ON b.bettype = s.bettype
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS ba WITH (NOLOCK) ON b.transid = ba.TransID

			IF @StatusFilter <> '1,2,3,4'
			BEGIN
				UPDATE b
				SET b.SettlementStatus = m.SettlementStatus
				FROM #Data AS b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.Product = 'SB' AND m.matchid = b.matchid

				IF ',' + @StatusFilter + ',' NOT LIKE '%,1,%'	-- Not include Running, Waiting
				BEGIN
					DELETE b
					FROM #Data AS b
						LEFT JOIN dbo.MarkedTransaction AS mt WITH (NOLOCK) ON b.transid = mt.TransId
					WHERE Product <> 'SB'
						OR (Product = 'SB'
							AND (Status = 'Waiting'																										-- Waiting
								OR (Status = 'Running' AND ISNULL(SecAcceptFlag, 0) = 1 AND ISNULL(CheckTime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)	-- Waiting (Second Accept)
								OR (Status = 'Running' AND ISNULL(SettlementStatus, 0) & 13 = 0 AND mt.TransId IS NULL)))								-- Running (normal)
				END
				
				IF ',' + @StatusFilter + ',' NOT LIKE '%,2,%'		-- Not include Result Pending
					OR ',' + @StatusFilter + ',' NOT LIKE '%,3,%'	-- Not include Under Settlement
				BEGIN
					DELETE b
					FROM #Data AS b
					WHERE Product = 'SB'
						AND Status = 'Running'
						AND NOT EXISTS (SELECT 1 FROM dbo.MarkedTransaction WITH (NOLOCK) WHERE TransId = b.TransId)
						AND (ISNULL(SecAcceptFlag, 0) = 0 OR ISNULL(CheckTime, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
						AND ((',' + @StatusFilter + ',' NOT LIKE '%,2,%' AND ISNULL(SettlementStatus, 0) & 1 <> 0)			-- Result Pending
							OR (',' + @StatusFilter + ',' NOT LIKE '%,3,%'
								AND ISNULL(SettlementStatus, 0) & 12 <> 0
								AND ISNULL(SettlementStatus, 0) & 1 = 0))		-- Under Settlement
				END

				IF ',' + @StatusFilter + ',' NOT LIKE '%,4,%'	-- Not include Pending
				BEGIN
					DELETE b
					FROM #Data AS b
					WHERE Product = 'SB'
						AND Status = 'Running'
						AND EXISTS (SELECT 1 FROM dbo.MarkedTransaction WITH (NOLOCK) WHERE TransId = b.TransId)
				END
			END

			DELETE #Data
			WHERE Product = 'Unknown'
				OR Product IS NULL
				OR BetType IN (901, 902, 903, 904, 911, 912, 913, 914)
				OR BetType BETWEEN 801 AND 899
				OR (@ShowSB = 0
					AND Product IN ('SB', 'Parlay', 'Outright')
					AND BATransId IS NULL)
				OR (@ShowBA = 0
					AND Product IN ('SB', 'Parlay', 'Outright')
					 AND BATransId IS NOT NULL)

			-- Get data for summary ticket of multiple Bonus/Cash sub tickets
			IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
			BEGIN
				DECLARE @RefCodeTmp TABLE (
					RefCode	BIGINT,
					TransId	BIGINT,
					Stake	MONEY
				)

				-- Prepare temp table
				INSERT INTO @RefCodeTmp
				SELECT
					RefCode,
					MIN(TransId) AS TransId,
					SUM(Stake) AS Stake
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

			-- Get exchange rate
			INSERT INTO #ExchangeRate
			SELECT
				e.ExchangeId,
				CASE
					WHEN @BaseCurrency = 'MYR' THEN e.MYR
					WHEN @BaseCurrency = 'USD' THEN e.USD
					WHEN @BaseCurrency = 'EUR' THEN e.EUR
					WHEN @BaseCurrency = 'CNY' THEN e.CNY
					WHEN @BaseCurrency = 'IDR' THEN e.IDR
					WHEN @BaseCurrency = 'GBP' THEN e.GBP
					WHEN @BaseCurrency = 'THB' THEN e.THB
					WHEN @BaseCurrency = 'INH' THEN e.INH
					ELSE 1
				END AS Rate
			FROM Lrf_f_GetExchangeDaily(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)) AS e
			WHERE EXISTS (SELECT 1 FROM #Data WHERE Currency = e.ExchangeId)

			-- Get sort text
			IF @ConvertToBaseCur = 1 AND @Sort LIKE '%Stake%'
			BEGIN
				DECLARE @CharIndex TINYINT

				SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

				SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
			END

			-- Return data
			SELECT
				@TotalRows = COUNT(b.TransId),
				@SumStake = SUM(b.Stake * ISNULL(e.Rate, 1))
			FROM #Data AS b
				LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.Currency

			IF @ConvertToBaseCur = 0
			BEGIN
				DELETE FROM #ExchangeRate
			END

			DECLARE @RowStart INT,
				@RowEnd INT

			SELECT @PageIndex = @PageIndex - 1,
				@RowStart = @PageSize * @PageIndex + 1,
				@RowEnd = @RowStart + @PageSize - 1

			DECLARE @Sql NVARCHAR(2000)

			SET @Sql = 
				N'SELECT a.*
				FROM
					(
						SELECT
							ROW_NUMBER() OVER (ORDER BY ' + @Sort +') AS RowNum,
							d.*
						FROM #Data AS d' +
						CASE
							WHEN @Sort LIKE '%e.Rate%' THEN N'
							LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = d.Currency'
							ELSE N' '
						END + N'
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum'

			INSERT INTO #PagingData
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			UPDATE b
			SET
				TransId = CASE
							WHEN b.Product = 'Parlay' AND b.BetType = 29 AND ISNULL(b.BetId, 0) > 0 THEN b.BetId
							ELSE b.TransId
						END,
				SportType = CASE
								WHEN b.Product IN ('Keno', 'Lottery') THEN b.ProductId
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
								WHEN b.Product IN ('Outright') THEN l.sporttype
								WHEN b.Product IN ('VR') THEN vr.SportType
								ELSE 0
							END,
				BetTeam = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2') THEN b.BetTeam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2') THEN b.Hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN b.Product IN ('SB', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2') THEN b.Hdp2
							ELSE 0
						END,
				OddsType = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.OddsType
							ELSE 0
						END,
				Odds = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'Keno', 'ParlayVS2', 'Lottery') THEN b.Odds
							ELSE 0
						END,
				MOdds = CASE 
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2')  THEN b.modds 
							ELSE 0
						END,
				Status = CASE
							WHEN b.Product = 'SB'
								AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							WHEN b.Product = 'Parlay' AND b.status = 'running' THEN
								CASE
									WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
												WHERE bm.custid = b.custid
													AND bm.refno = b.refno
													AND (bm.status = 'waiting'
														OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
										THEN 'Waiting'
									ELSE b.status
								END
							WHEN b.Product = 'SB' AND b.status = 'running' AND mt.TransId IS NOT NULL THEN 'Pending'
							ELSE b.status
						END,
				SettlementStatus = CASE
										WHEN b.Product IN ('SB') THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
				LiveIndicator = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveindicator
									ELSE 0
								END,
				LiveHomeScore = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2') THEN b.livehomescore
									ELSE 0
								END,
				LiveAwayScore = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.liveawayscore
									ELSE 0
								END,
				LeagueId = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
								WHEN b.Product IN ('Outright') THEN o.leagueid
								WHEN b.Product IN ('VR') THEN vr.LeagueID
								ELSE 0
							END,
				MatchId = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
								WHEN b.Product IN ('VR') THEN b.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
								WHEN b.Product IN ('Outright') THEN o.matchcode
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
								ELSE ''
							END,
				Race = CASE
							WHEN b.Product IN ('Outright') THEN o.groupmatch
							WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
							ELSE ''
						END,
				EventDate = CASE
								WHEN b.Product IN ('SB') THEN m.GlobalShowTime
								ELSE b.WinLostDate
							END,
				HomeId = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.homeid
							WHEN b.Product IN ('Outright') THEN o.teamid
							WHEN b.Product IN ('VR') THEN vo.RacerID
							ELSE 0
						END,
				AwayId = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
							ELSE 0
						END,
				BetStatus = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				Placing = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
								ELSE ''
							END,
				ShowTime = CASE
								WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
								ELSE ''
							END,
				BetCheck = CASE
								WHEN b.Product IN ('Parlay', 'ParlayVS2') THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.custom2, '')
								WHEN b.Product IN ('SB') THEN ISNULL(b.betcheck, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN b.Product IN ('SB', 'VS2', 'Keno', 'Lottery') THEN ISNULL(b.transdesc, '')
								ELSE ''
							END,
				OddsSpread = CASE
								WHEN b.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
								ELSE 0
							END,
				BetdaqId = CASE
								WHEN b.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
								ELSE -1
							END,
				ExtraInfo = CASE
								WHEN b.Product IN ('SB') THEN ISNULL(b.ExtraInfo, '')
								ELSE ''
							END,
				OriginalStake = CASE
									WHEN b.Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
										ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
									ELSE 0
								END,
				OriginalBetType = CASE
									WHEN b.Product IN ('SB') AND b.stake <> 0 THEN -1
									ELSE 0
								END,
				WalletType = CASE
								WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
								ELSE 0
							END,
				RefCode = CASE
								WHEN b.Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
								ELSE 0
							END
			FROM #PagingData AS b
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
				LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
				LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				LEFT JOIN dbo.MarkedTransaction AS mt WITH (NOLOCK) ON b.transid = mt.TransId
		END
	END

	-- Get ticket detail
	-- Virtual Sports
	IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR')
	BEGIN
		INSERT INTO @Detail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * ISNULL(e.Rate, 1) AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #PagingData AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
			INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
			LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.Currency
		WHERE b.Product = 'VR'
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	SELECT
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
		a.TransId,
		a.RefNo,
		a.BetId,
		a.CustId,
		a.TransDate,
		a.WinLostDate,
		a.SportType,
		a.BetType,
		a.BetTeam,
		a.Hdp1,
		a.Hdp2,
		a.Odds,
		a.MOdds,
		a.OddsType,
		a.OddsSpread,
		a.Status,
		a.SettlementStatus,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Race,
		a.LeagueId,
		a.MatchId,
		a.MatchCode,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.Placing,
		a.BetStatus,
		a.ShowTime,
		a.Currency,
		a.Stake * ISNULL(e.Rate, 1) AS Stake,
		a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		a.Ip,
		a.BetFrom,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode
	FROM
		#PagingData AS a
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
		LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = a.Currency
	ORDER BY a.RowNum

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO







GRANT EXECUTE ON [dbo].[Lrf_BetList_Running] TO [bodbLicenseeNet]
GO

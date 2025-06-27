/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Exchange_Running]
	@AgentList			VARCHAR(MAX),
	@Username			VARCHAR(50)		= '',
	@BaseCurrency		VARCHAR(12),
	@ConvertToBaseCur	BIT				= 0,	-- Convert to base currency or not
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				NVARCHAR(50)	= N'BetPlaced DESC',
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT
AS

/*
	Created: 20240821@Kos
	Task: LAP - BTC Exchange Running
	DB: DBEXT.bodb02

	Revisions:
		- 20240821@Kos: Support BTC Exchange Running [#Redmine: 208108]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250627@Kos: Extend SelectionId data type from INT to BIGINT [#Redmine: 231714]
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
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	DECLARE @CustId INT = 0

	IF @Username <> ''
	BEGIN
		SET @CustId = -1

		SELECT @CustId = custid
		FROM dbo.Customer AS c WITH (NOLOCK)
		WHERE c.username = @Username
			AND EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)

		IF @CustId = -1
		BEGIN
			DECLARE @Site VARCHAR(10)

			SELECT @Site = site
			FROM dbo.Customer WITH (NOLOCK)
			WHERE custid IN (SELECT TOP(1) CustId FROM @TempAg)

			SELECT @CustId = c.custid
			FROM dbo.Customer AS c WITH (NOLOCK)
			WHERE c.username2 LIKE @Site + '$' + @Username
				AND EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
		END
	END

	CREATE TABLE #Data (
		BetId			BIGINT,
		CustId			INT,
		UserId			VARCHAR(16),
		CategoryType	SMALLINT,
		EventTypeName	VARCHAR(50),
		EventId			INT,
		EventName		VARCHAR(500),
		MarketId		VARCHAR(50),
		MarketName		VARCHAR(500),
		SelectionId		BIGINT,
		SelectionName	VARCHAR(100),
		Type			VARCHAR(10),
		BetPlaced		DATETIME,
		Currency		TINYINT,
		OddsAvg			SMALLMONEY,
		FancyBetRuns	MONEY,
		Stake			MONEY
	)

	CREATE TABLE #PagingData (
		RowNum			INT,
		BetId			BIGINT,
		CustId			INT,
		UserId			VARCHAR(16),
		CategoryType	SMALLINT,
		EventTypeName	VARCHAR(50),
		EventId			INT,
		EventName		VARCHAR(500),
		MarketId		VARCHAR(50),
		MarketName		VARCHAR(500),
		SelectionId		BIGINT,
		SelectionName	VARCHAR(100),
		Type			VARCHAR(10),
		BetPlaced		DATETIME,
		Currency		TINYINT,
		OddsAvg			SMALLMONEY,
		FancyBetRuns	MONEY,
		Stake			MONEY
	)

	IF @Username = ''
	BEGIN
		INSERT INTO #Data
		SELECT
			b.betID,
			b.CustID,
			b.userId,
			b.categoryType,
			b.eventTypeName,
			b.eventID,
			b.eventName,
			b.marketID,
			b.marketName,
			b.selectionID,
			b.selectionName,
			b.matchType AS Type,
			b.betPlaced,
			c.currency,
			b.matchAvgOdds AS OddsAvg,
			ISNULL(bm.txFancyBetRuns, b.fancyBetRuns) AS fancyBetRuns,
			b.matchStake / IIF(c.site = '12bet', e.ExVirtualRate, 1) AS Stake
		FROM bodb_3rdProduct.dbo.Bettrans_Exchange AS b WITH (NOLOCK)
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.CustID
			INNER JOIN @TempAg AS ta ON ta.CustId = c.recommend
			INNER JOIN dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = c.currency
			LEFT JOIN bodb_3rdProduct.dbo.BettransM_Exchange AS bm WITH (NOLOCK) ON b.betID = bm.BetID
		WHERE b.betstatus = 'Not Settled'
	END
	ELSE
	BEGIN
		INSERT INTO #Data
		SELECT
			b.betID,
			b.CustID,
			b.userId,
			b.categoryType,
			b.eventTypeName,
			b.eventID,
			b.eventName,
			b.marketID,
			b.marketName,
			b.selectionID,
			b.selectionName,
			b.matchType AS Type,
			b.betPlaced,
			c.currency,
			b.matchAvgOdds AS OddsAvg,
			ISNULL(bm.txFancyBetRuns, b.fancyBetRuns) AS fancyBetRuns,
			b.matchStake / IIF(c.site = '12bet', e.ExVirtualRate, 1) AS Stake
		FROM bodb_3rdProduct.dbo.Bettrans_Exchange AS b WITH (NOLOCK)
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.CustID
			INNER JOIN dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = c.currency
			LEFT JOIN bodb_3rdProduct.dbo.BettransM_Exchange AS bm WITH (NOLOCK) ON b.betID = bm.BetID
		WHERE b.betstatus = 'Not Settled' AND b.CustID = @CustId
	END

	CREATE TABLE #ExchangeRate (
		ExchangeId	INT,
		Rate		FLOAT
	)

	-- Get exchange rate
	INSERT INTO #ExchangeRate
	SELECT
		e.ExchangeId,
		e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), @BaseCurrency, '') AS e
	WHERE EXISTS (SELECT 1 FROM #Data WHERE Currency = e.ExchangeId)

	-- Get sort text
	IF @Sort LIKE '%Stake%'
	BEGIN
		DECLARE @CharIndex TINYINT

		SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

		SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
	END

	SELECT
		@TotalRows = COUNT(b.BetId),
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

	SELECT
		b.BetId,
		b.CustId,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
		b.UserId,
		b.CategoryType,
		b.EventTypeName,
		b.EventId,
		b.EventName,
		b.MarketId,
		b.MarketName,
		b.SelectionId,
		b.SelectionName,
		b.Type,
		b.BetPlaced,
		b.Currency,
		b.OddsAvg,
		b.FancyBetRuns,
		CAST(b.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake
	FROM #PagingData AS b
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.CustId
		LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.Currency

	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO

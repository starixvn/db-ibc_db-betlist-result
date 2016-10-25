USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_CB_Detail]
	@LicenseeId	INT,
	@UserId		INT,
	@CustId		INT,
	@RefNo		BIGINT
AS

/*
	Created by: Kos@20160915
	Task: Get details info for Colossus Bets ticket
	DB: DBEXT.bodb02
	Original: 
	
	Revisions:
*/

BEGIN
	SET NOCOUNT ON

	-- Get currency (for security)
	DECLARE @Currency INT

	SELECT CurrencyId
	INTO #Currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)	-- System is default=1 (LRF)

	SELECT @Currency = c.currency 
	FROM dbo.custinfo AS c WITH (NOLOCK)
		INNER JOIN #Currency AS cy ON c.currency = cy.CurrencyId
	WHERE c.custid = @CustId

	DROP TABLE #Currency

	-- Get winlostdate of main ticket to use for exchange rate
	DECLARE
		@TransId		BIGINT,
		@WinLostDate	SMALLDATETIME,
		@StatusId		TINYINT

	SELECT TOP 1
		@TransId = translogid
	FROM dbo.translog WITH (NOLOCK)
	WHERE translogid = @RefNo
		AND gameID = 18000
		AND custid = @CustId
		AND statusID IN (0, 1)

	IF @TransId IS NOT NULL
		SET @WinLostDate = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)

	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP 1
			@WinLostDate = winlostdate,
			@StatusId = statusID
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE refno = @RefNo
			AND bettype = 18000
			AND custid = @CustId
	END

	IF @StatusId IN (0, 1)
		SET @WinLostDate = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)

	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP 1
			@WinLostDate = winlostdate
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE refno = @RefNo
			AND bettype = 18000
			AND custid = @CustId
	END

	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP 1
			@WinLostDate = winlostdate
		FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE refno = @RefNo
			AND bettype = 18000
			AND custid = @CustId
	END

	DECLARE @Data TABLE (
		TransId		BIGINT,
		TransDate	DATETIME,
		BetType		INT,
		Sold		SMALLMONEY,
		WinLost		MONEY,
		StatusId	TINYINT,
		Status		NVARCHAR(10),
		Discount	SMALLMONEY,
		Comm		MONEY,
		OddsSpread	MONEY
	)

	-- Get detail tickets
	IF @WinLostDate IS NOT NULL
	BEGIN
		INSERT INTO @Data
		SELECT transid,
			transdate,
			bettype,
			hdp1 AS Sold,
			(winlost - stake) AS WinLost,
			statusid,
			status,
			discount,
			comm,
			ISNULL(oddsspread, 0) AS OddsSpread
		FROM dbo.bettransm WITH (NOLOCK)
		WHERE refno = @RefNo
			AND custid = @CustId
			AND bettype BETWEEN 18001 AND 18006

		UNION

		SELECT transid,
			transdate,
			bettype,
			hdp1 AS Sold,
			(winlost - stake) AS WinLost,
			statusid,
			status,
			discount,
			comm,
			ISNULL(oddsspread, 0) AS OddsSpread
		FROM dbo.bettransm14 WITH (NOLOCK)
		WHERE refno = @RefNo
			AND bettype BETWEEN 18001 AND 18006
	
		UNION 
	
		SELECT transid,
			transdate,
			bettype,
			hdp1 AS Sold,
			(winlost - stake) AS WinLost,
			statusid,
			status,
			discount,
			comm,
			ISNULL(oddsspread, 0) AS OddsSpread
		FROM DBARC.bodb_archive.dbo.bettransm WITH (NOLOCK)
		WHERE refno = @RefNo
			AND bettype BETWEEN 18001 AND 18006
	END

	SELECT
		b.TransId,
		b.TransDate,
		b.BetType,
		b.Sold,
		b.StatusId,
		b.Status,
		b.Discount,
		b.OddsSpread,
		b.WinLost,
		CAST(b.WinLost * e.USD AS MONEY) AS WinLostUSD,
		CAST(b.WinLost * e.EUR AS MONEY) AS WinLostEUR,
		CAST(b.WinLost * e.MYR AS MONEY) AS WinLostMYR,
		CAST(b.WinLost * e.GBP AS MONEY) AS WinLostGBP,
		b.Comm,
		CAST(b.Comm * e.USD AS MONEY) AS CommUSD,
		CAST(b.Comm * e.EUR AS MONEY) AS CommEUR,
		CAST(b.Comm * e.MYR AS MONEY) AS CommMYR,
		CAST(b.Comm * e.GBP AS MONEY) AS CommGBP
	FROM @Data AS b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@WinLostDate, @WinLostDate)) AS e ON e.exchangeid = @Currency
	ORDER BY b.TransId ASC
END



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_CB_Detail] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_CB_Detail] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_CB_Detail] TO [vnteam] AS [dbo]
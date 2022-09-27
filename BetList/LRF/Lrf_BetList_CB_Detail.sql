/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_CB_Detail]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@RefNo			BIGINT,
	@BaseCurrency	VARCHAR(12)
AS

/*
	Created by: Kos@20160915
	Task: Get details info for Colossus Bets ticket
	DB: DBEXT.bodb02

	Revisions:
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20190528@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
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

	-- Get currency (for security)
	DECLARE @Currency	INT,
		@ExRate			FLOAT

	SELECT @Currency = currency
	FROM dbo.custinfo WITH (NOLOCK)
	WHERE custid = @CustId
		AND currency IN (SELECT DISTINCT Currency FROM @TempAg)

	-- Get exchange rate
	SELECT @ExRate = e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@WinLostDate, @WinLostDate, @BaseCurrency, '') AS e
	WHERE e.ExchangeId = @Currency

	SELECT
		b.TransId,
		b.TransDate,
		b.BetType,
		b.Sold,
		b.StatusId,
		b.Status,
		b.Discount,
		b.OddsSpread,
		b.WinLost * @ExRate AS WinLost,
		b.Comm * @ExRate AS Comm
	FROM @Data AS b
	ORDER BY b.TransId ASC
END
GO

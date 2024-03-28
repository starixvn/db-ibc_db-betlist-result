/*<info serverAlias="DBSID-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_CashOut_History]
	@TransId		BIGINT,
	@CustId			INT,
	@WinLostDate	SMALLDATETIME,
	@Currency		INT,
	@BaseCurrency	VARCHAR(12)	= ''
AS

/*
	Created: 20220819@Kos
	Task: LAP - Bet List - Get ticket detail of Cash Out history - SiteDB
	DB: DBSID.bodb02

	Revisions:
		- 20220819@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Today	SMALLDATETIME,
		@Rate		FLOAT			= 1

	-- Get exchange rate
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	IF @WinLostDate > @Today
		SET @WinLostDate = @Today

	IF @BaseCurrency <> ''
	BEGIN
		SELECT @Rate = Rate
		FROM dbo.SiteDB_Lrf_f_GetExchangeRate(@WinLostDate, @WinLostDate, @BaseCurrency, '')
		WHERE ExchangeId = @Currency
	END

	-- Return data
	SELECT
		TransId,
		CashoutExtraInfo,
		@Rate AS Rate
	FROM dbo.CashOutSelling WITH (NOLOCK)
	WHERE TransID = @TransId AND Custid = @CustId
END
GO

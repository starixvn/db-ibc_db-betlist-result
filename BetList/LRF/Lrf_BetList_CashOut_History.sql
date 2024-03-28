/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_CashOut_History]
	@TransId		BIGINT,
	@CustId			INT,
	@WinLostDate	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@Currency		INT,
	@BaseCurrency	VARCHAR(12)	= ''
AS

/*
	Created: Kos@20220404
	Task: Get Cash Out ticket history
	DB: DBACC.bodb02

	Revisions:
		- 20220404@Kos: Created [Redmine: #169007]
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
		FROM dbo.Lrf_f_GetExchangeRate(@WinLostDate, @WinLostDate, @BaseCurrency, '')
		WHERE ExchangeId = @Currency
	END

	-- Return data
	IF @WinLostDate >= @BalanceUpDay
	BEGIN
		SELECT
			TransId,
			CashoutExtraInfo,
			@Rate AS Rate
		FROM dbo.CashOutSelling WITH (NOLOCK)
		WHERE TransID = @TransId AND Custid = @CustId
	END
	ELSE
	BEGIN
		SELECT
			TransId,
			CashoutExtraInfo,
			@Rate AS Rate
		FROM bodb_Archive.dbo.CashOutSelling_bk WITH (NOLOCK)
		WHERE TransID = @TransId AND Custid = @CustId
	END
END
GO

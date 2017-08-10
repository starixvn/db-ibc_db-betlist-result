USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[U3_BetList_SelBettype]
	@CustId			INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@MoveBetsDay	DATETIME,
	@BalanceUpDay	DATETIME
AS

/*
	Created: Dom@20150105
	DB: DBAGE.bodb02
	Task: Get bettype in bettrans table for U3
	Revisions:
		- 20170814@Kos: Support Lucky 3 [#Redmine: 75277]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (3, 4, 7, 26)

	DECLARE @BetTypeTable TABLE (bettype INT)

	DECLARE @TempFromDate DATETIME,
		@TempToDate DATETIME

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		INSERT INTO @BetTypeTable
		SELECT DISTINCT bettype
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE bettype < 19001
			AND custid = @CustId
			AND winlostdate BETWEEN @TempFromDate AND @todate
		UNION
		SELECT DISTINCT gameID AS bettype
		FROM dbo.translog WITH (NOLOCK)
		WHERE winlostdate BETWEEN @TempFromDate AND @todate
			AND statusID = 0
	END

	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @BalanceUpDay < @FromDate
			SELECT @BalanceUpDay = @FromDate

		INSERT INTO @BetTypeTable
		SELECT DISTINCT bettype
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE bettype < 19001
			AND custid = @CustId
			AND winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @ToDate
	
		INSERT INTO @BetTypeTable
		SELECT DISTINCT bettype
		FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE bettype < 19001
			AND custid = @CustId
			AND winlostdate BETWEEN @FromDate AND @TempToDate
	END

	SELECT
		bt.typeid,
		bt.typenamee
	FROM dbo.bettype AS bt WITH (NOLOCK)
		INNER JOIN (SELECT DISTINCT bettype FROM @BettypeTable) AS btt ON bt.typeid = btt.bettype
		INNER JOIN @SportBettype AS mtx ON mtx.bettype = bt.typeid
END


GO
GRANT	EXECUTE	ON	U3_BetList_SelBettype	TO	bodbAdminNet
GRANT	VIEW DEFINITION	ON	U3_BetList_SelBettype	TO	vnteam
GRANT	EXECUTE	ON	U3_BetList_SelBettype	TO	bodbExtAccNet
GO
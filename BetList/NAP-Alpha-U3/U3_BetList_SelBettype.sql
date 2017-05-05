USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[U3_BetList_SelBettype]    Script Date: 5/5/2017 5:21:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.U3_BetList_SelBettype    Script Date: 1/15/2015 10:22:01 PM ******/
/****** Object:  Stored Procedure dbo.U3_BetList_SelBettype    Script Date: 1/14/2015 2:40:23 PM ******/
ALTER PROCEDURE [dbo].[U3_BetList_SelBettype]
	@CustID int
	,@FromDate datetime
	,@ToDate datetime
	,@MoveBetsDay datetime 
	,@BalanceUpDay datetime 
AS 

/*	Created: Dom
	Date:05/01/2015
	DB: DBAGE/BODB02
	Task: Get bettype in bettrans table
	Revisions:
	
*/
BEGIN

SET NOCOUNT ON  

	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT,EventType INT)
	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4

	DECLARE @BettypeTable TABLE (bettype INT)

	Declare @TempFromDate datetime
	Declare @TempToDate datetime

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay 
			SET @TempFromDate =  dateadd(day,1,@MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate
		
		INSERT INTO @BettypeTable
		SELECT 
			DISTINCT bettype 
			FROM dbo.bettrans (nolock)
		WHERE 
			bettype < 19001 
			AND custid = @CustID
			AND winlostdate BETWEEN @TempFromDate AND @todate
		UNION 
		SELECT 
			DISTINCT gameID bettype 
			FROM dbo.translog (nolock)
		WHERE 
			winlostdate BETWEEN @TempFromDate AND @todate
			AND statusID = 0
		
			
	END
	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			set @TempToDate = @MoveBetsDay
		ELSE
			set  @TempToDate = @ToDate
	
		IF @BalanceUpDay < @FromDate 
			SELECT @BalanceUpDay=@FromDate
	
		INSERT INTO @BettypeTable
		SELECT 
			DISTINCT bettype 
			FROM dbo.bettrans14 (nolock)
		WHERE 
			bettype < 19001 
			AND custid = @CustID
			AND winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @todate
	
		INSERT INTO @BettypeTable
		SELECT 
			DISTINCT bettype
		FROM DBARC.bodb_archive.dbo.bettrans_bk with (nolock)
		WHERE 
			bettype < 19001
			AND custid = @CustID
			AND winlostdate BETWEEN @fromdate AND @TempToDate 
	END


	SELECT 
		typeid,
		typenamee
	FROM bettype bt (nolock)
	INNER JOIN (SELECT DISTINCT bettype FROM  @BettypeTable) btt on bt.typeid = btt.bettype
	INNER JOIN @SportBettype mtx ON mtx.bettype = bt.typeid
	WHERE mtx.ProductID IN(3,4,7)

END


GRANT	EXECUTE	ON	U3_BetList_SelBettype	TO	bodbAdminNet
GRANT	VIEW DEFINITION	ON	U3_BetList_SelBettype	TO	vnteam
GRANT	EXECUTE	ON	U3_BetList_SelBettype	TO	bodbExtAccNet
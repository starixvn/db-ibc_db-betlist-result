USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelDeleted_UserList]    Script Date: 4/8/2014 4:41:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelDeleted_UserList]
	@LicenseeId		INT,
	@UserId			INT,
	@CurrencyId		INT				= 0,
	@LicenseeType	VARCHAR(100)	= NULL
AS

/*
	Created by: Henry@20101210 
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelDeleted_UserList_Ag]

	Revisions:
		- 20110302@Henry: Allow to choose all type of licensee AND all currency 
		- 20110325@Henry: Support username2 to the list
		- 20121004@Jim: Replace @currencyname input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130809@Jim: Offer Virtual Horse Racing
		- 20140403@Hannah: Offer Keno
		- 20140408@Florent: Add more condition for Keno
		- 20141111@Jim: Use f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		- 20150409@Winnie: Apply spottype bettype matrix 
		- 20150514@Winnie: Fix bug
		- 20150609@Edward : Support BetTrade
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
*/

BEGIN
	SET NOCOUNT ON

	SELECT currencyID,
		LicenseeID
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @UserId, 1)-- System is default=1 (LRF)
	WHERE (@CurrencyId = 0
		OR (@CurrencyId <> 0 AND CurrencyID = @CurrencyId))

	------------
	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT, EventType INT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <> 1 OR Bettype NOT IN (903, 904)

	------------
	DECLARE @TempAg AS TABLE (CustId INT, Currency INT)

	INSERT INTO @TempAg
	SELECT CustID
		,Currency
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(@LicenseeId) AS lc
		INNER JOIN #Currency AS c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE [Description] = COALESCE(@LicenseeType, [Description])

	DROP TABLE #Currency

	DECLARE @bc TABLE (CustId INT, BetCount INT)

	INSERT INTO @bc
	SELECT b.custid,
		SUM(1) AS BetCount
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		INNER JOIN @TempAg AS ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE b.statusID IN (101, 102)
		AND (sbt.ProductID NOT IN (1, 2, 5, 8)
			OR (sbt.ProductID = 1 AND sbt.EventType <> 2)
			OR (sbt.ProductID = 5 AND sbt.EventType <> 3))
		AND m.eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
	GROUP BY b.custid

	-- Horse Racing, Outright
	INSERT INTO @bc
	SELECT b.custid,
		SUM(1) AS BetCount
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
		INNER JOIN @TempAg AS ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE b.statusID IN (101, 102)
		AND (sbt.ProductID = 2
			OR (sbt.ProductID = 1 AND sbt.EventType = 2))
		AND m.eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
	GROUP BY b.custid

	-- Virtual Sports (EventType = 3)
	INSERT INTO @bc
	SELECT b.custid,
		SUM(1) AS BetCount
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.VSOutright AS m WITH (NOLOCK) ON b.oddsid = m.orid
		INNER JOIN @TempAg AS ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE b.statusID IN (101, 102)
		AND sbt.ProductID = 5
		AND sbt.EventType = 3
		AND m.eventdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
	GROUP BY b.custid

	-- Keno
	INSERT INTO @bc
	SELECT b.custid,
		SUM(1) AS BetCount
	FROM 
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @TempAg AS ag ON b.recommend = ag.CustId AND b.currency = ag.Currency
		INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
	WHERE 
		b.statusID IN (101, 102)
		AND b.winlostdate > DATEADD(DAY, -3, CURRENT_TIMESTAMP)
		AND sbt.ProductID = 8
	GROUP BY b.custid

	SELECT
		c.username,
		c.custid,
		SUBSTRING(c.username2, CHARINDEX('$',c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		SUM(betcount) AS BetCount
	FROM dbo.customer AS c WITH (NOLOCK)
		INNER JOIN @bc AS b ON c.custid = b.CustId
	WHERE c.roleid = 1
	GROUP BY c.username,
		c.custid,
		c.username2
END

GO

GRANT EXECUTE ON [dbo].[Lrf_BetList_SelDeleted_UserList] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelDeleted_UserList] TO [vnteam]
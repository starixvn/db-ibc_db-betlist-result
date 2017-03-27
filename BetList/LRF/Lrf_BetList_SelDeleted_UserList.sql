USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelDeleted_UserList]    Script Date: 4/8/2014 4:41:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelDeleted_UserList]
	@AgentList	VARCHAR(MAX)
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
		- 20150609@Edward: Support BetTrade
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160913@Kos: Don't support Colossus Bets [#Redmine: 63785]
		- 20170301@Kos: Support sub licensees [#Redmine: 71679]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
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
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

	-- Get SportBettypeMatrix
	DECLARE @SportBettype TABLE(ProductID INT, Bettype INT, EventType INT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <= 6 OR ProductID IN (8, 13, 25)

	DELETE FROM @SportBettype
	WHERE Bettype IN (903, 904, 913, 914)

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
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		SUM(b.BetCount) AS BetCount
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
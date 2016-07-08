USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes]    Script Date: 04/21/2016 04:37:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Age_Monitor_BetlistSel_Ag_AllBettypes    Script Date: 3/10/2016 11:14:13 PM ******/
/****** Object:  Stored Procedure dbo.Age_Monitor_BetlistSel_Ag_AllBettypes    Script Date: 3/9/2016 10:34:23 ******/

ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes]
	@custid			INT,
	@transid		BIGINT	= 0,
	@LimitRowCount	INT		= 20 
--WITH RECOMPILE
AS

/*
	Created: Johnson
	Task: Monitor lastest bets list( all bettypes and all sports)
	Date: 28/06/2011
	DB: DBAGE.BODB02
	Revision:
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20120827@Jamie: Add actual_stake for System Parlay Bet list 
		- 20130222@Elodie: Get custid value
		- 20130222@Elodie: Get oddsid value to use for Virtual HR
		- 20150318@Cody: Apply sporttype bettype matrix
		- 20150706@Bobby: Exclude Metric Gaming running ticket
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150904@Kos: Correct data type of temp table
		- 20160104@Kos: Support Sportsbook only
		- 20160125@Kos: Support PH All In One 1.2 [Redmine: #50897]
		- 20160308@Francis: Change to use inline function instead of table variable to enhance performance
	Parameter's Explanation:
		- @custid : agent's ID
		- @transid: lastest transid 
		- @LimitRowCount: max record return.
*/ 

BEGIN
	SET NOCOUNT ON

	DECLARE @isTest BIT,@SQL NVARCHAR(100) = OBJECT_NAME(@@PROCID)

	IF  (@SQL like '%_xtest%' OR @SQL like '%_xpre%' OR @SQL like '%_UAT1%' OR @SQL like '%_UAT2%' OR @SQL like '%_UAT3%' OR @SQL like '%_UAT4%')
	BEGIN
		SELECT @isTest = 1
	END
	ELSE
	BEGIN
		SELECT @isTest = 0
	END

	--DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	--INSERT INTO @SportBettype
	--			EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 4

	---- Only support Sportsbook
	--DELETE FROM @SportBettype
	--WHERE ProductID <> 1

	SELECT TOP(@LimitRowCount)
		b.custid,
		0 AS sporttype,
		b.matchid,
		0 AS leagueid,
		b.Username,
		b.bettype,
		b.transid,
		b.refno,
		b.transdate,
		'' AS matchcode,
		0 AS homeid,
		0 AS awayid,
		b.oddsid AS Race,
		b.betid,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.stake,
		b.actual_stake,
		CASE 
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status
		END AS status,
		b.betteam,
		b.IP,
		CONVERT(BIT, 0) AS isNeutral,
		b.oddstype,
		ISNULL(b.Betcheck, '') AS Betcheck,
		ISNULL(b.transdesc, '') AS transdesc,
		ISNULL(b.oddsspread, 0) AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		--INNER JOIN @SportBettype AS s ON b.bettype = s.BetType
		INNER JOIN dbo.f_SportBettypeMatrix_Sel_Mode4(1, 0, 0, 2, '', '', @IsTest) s ON b.bettype = s.Bettype
	WHERE b.recommend = @custid 
		AND b.transid > @transid
		AND b.statusID BETWEEN 0 AND 1
		AND b.bettype NOT BETWEEN 801 AND 806
	ORDER BY b.transid DESC

END


GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes] TO [vnteam] AS [dbo]
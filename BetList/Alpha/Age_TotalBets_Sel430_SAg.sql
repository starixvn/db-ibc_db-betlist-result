/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_TotalBets_Sel430_SAg]    Script Date: 1/25/2016 4:27:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Age_TotalBets_Sel430_SAg]
	@CustId		INT,
	@Language	VARCHAR(2) = 'E'
AS

/*
	Created: 20110915@TOM
	Task : Retrieve total bet of 1St Correct Score/Correct Score. (BetType: 4,30)
	DB: DBAGE.bodb02
	Original:Age_BetList_SelRunningByBettype_SAg

	Revisions:
		- 21Nov2011@Johnson: get matchid column
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
		- 20121004@Johnson: get comstatus to check double comm losing 	
		- 20140611@Dom: Add new bettype ht correct score 152
		- 20150407@Cody: Integrate new 60 bet types from BetRadar [Redmine: #32734]
		- 20151203@Kos: Include bet type 405 2H Correct Score [Redmine: #47959]
		- 20170721@Kos: Include bet type 416 Half Time/Full Time Correct Score (own) [Redmine: #53153]
*/

BEGIN
	SET NOCOUNT ON

	SELECT 
		m.sporttype,
		b.username,
		m.leagueID,
		b.bettype,
		b.transid,
		b.refno,
		m.matchid,
		m.matchcode,
		m.homeID,
		m.awayID,
		CONVERT(FLOAT, b.hdp1) AS hdp1,
		CONVERT(FLOAT, b.hdp2) AS hdp2,
		b.odds,
		b.modds,
		CASE 
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status
		END AS status,
		CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
		b.stake,
		b.actual_stake,
		b.transdate,
		b.betteam,
		b.betID,
		b.spositiontaking,
		b.mpositiontaking,
		b.apositiontaking,
		b.discount AS Adiscount,
		b.adiscount AS Mdiscount,
		b.sdiscount AS Sdiscount,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.IP,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.OddsType,
		ISNULL(b.transdesc, '') AS transdesc
 	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE b.SRecommend = @custid
		AND b.bettype IN (4, 30, 152, 165, 166, 405, 413, 414, 416)
		AND b.statusID IN (0, 1)
	ORDER BY b.status, b.transid
END

	

GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel430_SAg] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_TotalBets_Sel430_SAg] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_TotalBets_Sel430_SAg] TO vnteam
GO


 
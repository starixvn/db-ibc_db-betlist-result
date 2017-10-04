USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Acc_Rpt_DailyWLDirect_Result_Old]    Script Date: 2/14/2017 4:31:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Acc_Rpt_DailyWLDirect_Result_Old]
	@MatchId	INT,
	@BetType	INT,
	@TraderName	NVARCHAR(100) OUTPUT
AS

/*
	Created: Dom.Cao
	Task: show popup of match information
	DB: DBACC.bodb02
	Original: Acc_BetList_SelMatchResult_Old

	Revisions:
		- 20141023@Sophia: Get data from ResultDetail table (support Sporting solution) (RedmineID :#23671)
		- 20150415@Sophia: Support BetRadar
		- 20151215@Tom: Change data type of parameter @Sporttype from TINYINT to SMALLINT
					- Change DB06 to alias server DBACC (RedmineID :#48078)
		- 20170214@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70731]
					- Don't support result detail anymore [#Redmine: 70731]
					- Move SP from DBDW2.bodb_dwrs to DBACC.bodb02
		- 20170323@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170802@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20171004@Kos: Use table TradingBettypeMapping instead of hardcode [Redmine: #83679]
*/

BEGIN
	SET NOCOUNT ON

	-- Get match info and result
	SELECT
		m.betstatus,
		m.hthomescore,
		m.htawayscore,
		DATEDIFF(MINUTE, m.kickofftime, CURRENT_TIMESTAMP) AS PlayTime,
		m.leagueid,
		m.homeid,
		m.awayid,
		m.matchcode,
		m.kickofftime,
		m.eventdate,
		m.finalhomescore,
		m.finalawayscore,
		m.livehomescore,
		m.liveawayscore,
		CASE m.sporttype
			WHEN 5 THEN
				CASE ISNULL(r.SettlementStatusID, 0)
					WHEN 1 THEN 'Refund'
					WHEN 2 THEN 'Refund HT'
					WHEN 3 THEN 'Refund FT'
					ELSE m.eventstatus
				END
			ELSE
				CASE
					WHEN m.betstatus LIKE '%Abandoned 1H%' THEN 'Abandoned 1H'
					WHEN m.betstatus LIKE '%Abandoned 2H%' THEN 'Abandoned 2H'
					WHEN m.betstatus LIKE '%Refund FT%' THEN 'Refund FT'
					WHEN m.betstatus LIKE '%Refund HT%' THEN 'Refund HT'
					WHEN m.betstatus LIKE '%Refund%' THEN 'Refund'
					ELSE m.eventstatus
				END
		END AS EventStatus,
		ISNULL(mr.refund, 0) IsRefund,
		ISNULL(mr.calrefund, 0) IsCalRefund,
		ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
		m.goalrecord,
		ISNULL(mr.IsHTCal, 0) AS IsHTCal,
		ISNULL(mr.calculate, 0) AS Calculate,
		ISNULL(mr.IsPending, 0) AS IsPending
	FROM bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
		LEFT OUTER JOIN bodb_Archive.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
		LEFT JOIN bodb_Archive.dbo.ResultDetail_bk AS r WITH (NOLOCK) ON r.MatchId = m.matchid AND r.ResourceId = '00'
	WHERE m.matchid = @MatchId

	-- Get trader name
	SELECT @TraderName = c.username
	FROM bodb_Archive.dbo.Dot_Admin_Assignment_Operator_bk AS o WITH (NOLOCK)
		INNER JOIN dbo.customer AS c WITH (NOLOCK) ON o.OperatorID = c.custid
		INNER JOIN DBDW.bodb_Account.dbo.TradingBettypeMapping AS m WITH (NOLOCK)
			ON o.OperatorType = m.OperatorType AND o.bettype = m.TradingBetType
	WHERE o.matchid = @MatchId AND m.TicketBetType = @BetType

	DECLARE @SportType SMALLINT

	-- Get sport type
	SELECT @SportType = sporttype
	FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
	WHERE matchid = @MatchId

	-- Get result detail for Basketball and Tennis main result only
	SELECT
		MatchID,
		ResourceID,
		HomeValue,
		AwayValue,
		ResultStatusID,
		SettlementStatusID,
		OtherInfo
	FROM bodb_Archive.dbo.ResultDetail_bk WITH (NOLOCK)
	WHERE MatchID = @MatchId
			AND LEN(ResourceID) = 2
			AND (@SportType = 2
				OR (@SportType = 5 AND SettlementStatusID > 0))
	ORDER BY ResourceID
END




GO
GRANT EXECUTE ON [dbo].[Acc_Rpt_DailyWLDirect_Result_Old] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Acc_Rpt_DailyWLDirect_Result_Old] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_Rpt_DailyWLDirect_Result_Old] TO [vnteam]
GO

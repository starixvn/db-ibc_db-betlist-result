ALTER PROCEDURE [dbo].[Age_BetList_SelMatchResultNumberGame]
	@MatchId	INT
AS

/*
	Created: 20100908@Jacob
	Task: Get Result for Number Game
	DB: DBAGE.bodb02

	Revisions:
		- 20110721@Johnson: get column kickofftime, leagueid
		- 20110831@Johnson: correct event status when refund ticket
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20170525@Kos: Support Lucky 3 [#Redmine: 75277]
*/

BEGIN
	SET NOCOUNT ON

	IF EXISTS (SELECT 1 FROM dbo.bingoball WITH (NOLOCK) WHERE Matchid = @MatchId)
	BEGIN
		SELECT
			b.Matchid,
			b.Seq,
			b.Number,
			b.UpdateTime,
			m.kickofftime,
			m.leagueid,
			m.eventdate,
			CASE
				WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'
				WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
				WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'
				ELSE m.eventstatus
			END AS EventStatus,
			m.matchcode,
			m.livehomescore,
			m.liveawayscore,
			m.finalhomescore
		FROM dbo.bingoball AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.Matchid = m.matchid
		WHERE b.Matchid = @MatchId
		ORDER BY b.Seq
	END
	ELSE IF EXISTS(SELECT 1 FROM dbo.bingoball14 WITH (NOLOCK) WHERE Matchid = @MatchId)
	BEGIN
		SELECT
			b.Matchid,
			b.Seq,
			b.Number,
			b.UpdateTime,
			m.kickofftime,
			m.leagueid,
			m.eventdate,
			CASE
				WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'
				WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
				WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'
				ELSE m.eventstatus
			END AS EventStatus,
			m.matchcode,
			m.livehomescore,
			m.liveawayscore,
			m.finalhomescore
		FROM dbo.bingoball14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Matchid = m.matchid
		WHERE b.Matchid = @MatchId
		ORDER BY b.Seq
	END
	ELSE
	BEGIN
		SELECT
			b.Matchid,
			b.Seq,
			b.Number,
			b.UpdateTime,
			m.kickofftime,
			m.leagueid,
			m.eventdate,
			CASE
				WHEN m.betstatus LIKE 'Refund FT%' THEN 'Refund FT'
				WHEN m.betstatus LIKE 'Refund HT%' THEN 'Refund HT'
				WHEN m.betstatus LIKE 'Refund%' THEN 'Refund'
				ELSE m.eventstatus
			END AS EventStatus,
			m.matchcode,
			m.livehomescore,
			m.liveawayscore,
			m.finalhomescore
		FROM DBARC.bodb_Archive.dbo.bingoBall_bk AS b WITH (NOLOCK)
			INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.Matchid = m.matchid
		WHERE m.matchid = @MatchId
		ORDER BY b.Seq
	END
END


  
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultNumberGame] TO [bodbExtAccNet]
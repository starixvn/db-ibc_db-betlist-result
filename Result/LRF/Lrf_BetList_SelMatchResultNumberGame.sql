/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelMatchResultNumberGame]
	@MatchId INT
AS

/*
	Created: 20101210@Henry
	Task: Get Result for number game
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelMatchResultNumberGame]

	Revisions:
		- 20110927@Henry: Return more columns: kickofftime
		- 20190108@Kos: Support Happy 5 [Redmine: #103698]
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
			m.eventdate,
			m.eventstatus,
			m.matchcode,
			m.leagueid
		FROM dbo.bingoBall AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.Matchid = m.matchid
		WHERE b.matchid = @MatchId
		ORDER BY b.Seq
	END
	ELSE IF EXISTS (SELECT 1 FROM dbo.bingoBall14 WITH (NOLOCK) WHERE Matchid = @MatchId)
	BEGIN
		SELECT
			b.Matchid,
			b.Seq,
			b.Number,
			b.UpdateTime,
			m.kickofftime,
			m.eventdate,
			m.eventstatus,
			m.matchcode,
			m.leagueid
		FROM dbo.bingoBall14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Matchid = m.matchid
		WHERE b.matchid = @MatchId
		ORDER BY b.Seq
	END
	ELSE
	BEGIN
		SELECT
			b.matchid,
			b.Seq,
			b.number,
			b.updatetime,
			m.kickofftime,
			m.eventdate,
			m.eventstatus,
			m.matchcode,
			m.leagueid
		FROM DBARC.bodb_Archive.dbo.bingoBall_bk AS b WITH (NOLOCK)
			INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE m.matchid = @MatchId
		ORDER BY b.Seq 
	END
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelMatchResultNumberGame] TO [bodbLicenseeNet] AS [dbo]
GO

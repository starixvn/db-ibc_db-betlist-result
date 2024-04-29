/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_MatchSelByLeague_Detail]
	@MatchId INT
AS

/*
	Created: 20141021@Jim
	Task: Retrieve result detail of a match
	DB: DBEXT.bodb02

	Revisions:
		- 20150407@Sophia: Support to get BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161021@Kos: Exclude Fast Market result [#Redmine: 56589]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170405@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170919@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20171106@Kos: Support PH AIO 3 [#Redmine: 83970]
		- 20180103@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180320@Kos: Exclude Fast Market 2 result [#Redmine: 90879]
		- 20180412@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20181015@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
					- Move eventstatus data transform to web (no change for Tennis)
		- 20181018@Kos: Support E-Sports 2 [#Redmine: 100721]
		- 20190814@Kos: Support PH AIO phase 4b [Redmine: #118300]
					- Change for "Next Goal" [Redmine: #115235]
		- 20191107@Kos: Support Badminton AIO phase 2 [Redmine: #120336]
		- 20191206@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20200515@Kos: Support PH AIO phase 5.1 [Redmine: #132770]
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
		- 20210223@Kos: Support Cricket AIO [Redmine: #150386]
		- 20210420@Kos: Support Time Machine Over/Under [Redmine: #153302]
		- 20210922@Kos: Support Cricket AIO 1.2 [Redmine: #160452]
		- 20220315@Kos: Support Cricket phase 2 [Redmine: #168034]
		- 20220325@Kos: Extend OtherInfo length [Redmine: #168034]
		- 20220623@Kos: Support more map for E-Sports [Redmine: #174251]
		- 20220722@Kos: Support Volleyball AIO [Redmine: #175143]
		- 20230321@Kos: Change Display HT Score for some Special League of Soccer [Redmine: #181331]
		- 20240412@Kos: Change display for Last Series child match [Redmine: #202484]
		- 20240429@Kos: Return LeagueGroupId to support Jollysports [Redmine: #203258]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT

	DECLARE @Detail TABLE (
		MatchId				INT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(50),
		AwayValue			VARCHAR(50),
		ResultStatusId		TINYINT,
		SettlementStatusId	TINYINT,
		OtherInfo			VARCHAR(2000)
	)

	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.leagueid,
			l.LeagueGroupID,
			m.matchid,
			m.matchcode,
			m.eventdate,
			CASE
				WHEN m.sporttype NOT IN (161, 180, 186) THEN m.GlobalShowTime
				ELSE m.kickofftime
			END AS KickOffTime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE m.sporttype
				WHEN 5 THEN
					CASE ISNULL(r.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS EventStatus,
			m.showtime,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.GoalRecord,
			ISNULL(m.homeid2, 0) AS homeid2,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore,
			ISNULL(mr.MainType, 0) AS MainType,
			ISNULL(mr.SubType, 0) AS SubType
		FROM dbo.match AS m WITH (NOLOCK)
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail
		IF @SportType IN (1, 2, 5)
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND ((@SportType = 1							-- Soccer
						AND SettlementStatusID > 0
						AND (ResourceID NOT IN ('08', '09')
							OR HomeValue LIKE '%a%'
							OR HomeValue LIKE '%h%')
						AND ResourceID NOT IN ('00', '01', '04', '05', '14F', '14L', '127F', '127L', '135', '168', '173', '174', '175', '176', 
							'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215', '488', '489', '490', '376')
						AND ResourceID NOT LIKE '160%'
						AND ResourceID NOT LIKE '164%'
						AND ResourceID NOT LIKE '169%'
						AND ResourceID NOT LIKE '180%'
						AND ResourceID NOT LIKE '216%'
						AND ResourceID NOT LIKE '217%'
						AND ResourceID NOT LIKE '221%'
						AND ResourceID NOT LIKE '222%'
						AND ResourceID NOT LIKE '223%'
						AND ResourceID NOT LIKE '224%'
						AND ResourceID NOT LIKE '225%'
						AND ResourceID NOT LIKE '226%'
						AND ResourceID NOT LIKE '227%'
						AND ResourceID NOT LIKE '228%'
						AND ResourceID NOT LIKE '229%'
						AND ResourceID NOT LIKE '486%'
						AND ResourceID NOT LIKE '487%')
					OR (@SportType = 5							-- Tennis
						AND SettlementStatusID > 0)
					OR (@SportType = 2							-- Basketball
						AND (LEN(ResourceID) = 2
							OR SettlementStatusID > 0)))
		END
		ELSE IF @SportType IN (6, 9, 50)		-- Volleyball, Badminton, Cricket
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailOS WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) = 2
					OR (LEN(ResourceID) = 4 AND @SportType IN (6, 9))
					OR (SettlementStatusID > 0
						AND (@SportType IN (6, 9)
							OR (@SportType = 50 AND ResourceID IN ('9400', '9401', '9442', '9443', '9446', '9447', '9450', '9449', '9452', '9453', 
								'94511', '96151')))))
		END
		ELSE IF @SportType = 43		-- E-Sports
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) IN (2, 3) OR SettlementStatusID > 0)
		END
		ELSE IF @SportType = 193
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchID,
				ResourceId,
				Custom1 AS HomeValue,
				Custom2 AS AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail3rd WITH (NOLOCK)
			WHERE MatchID = @MatchId AND SettlementStatusID > 0
		END
	END
	ELSE
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.leagueid,
			l.LeagueGroupID,
			m.matchid,
			m.matchcode,
			m.eventdate,
			CASE
				WHEN m.sporttype NOT IN (161, 180, 186) THEN m.GlobalShowTime
				ELSE m.kickofftime
			END kickofftime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE m.Sporttype
				WHEN 5 THEN
					CASE ISNULL(r.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS eventstatus,
			m.showtime,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			m.GoalRecord,
			ISNULL(m.homeid2, 0) AS homeid2,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			0 AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore,
			ISNULL(mr.MainType, 0) AS MainType,
			ISNULL(mr.SubType, 0) AS SubType
		FROM dbo.match14 AS m WITH (NOLOCK)
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS r WITH (NOLOCK) ON r.matchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail
		IF @SportType IN (1, 2, 5)
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail14 WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND ((@SportType = 1							-- Soccer
						AND SettlementStatusID > 0
						AND (ResourceID NOT IN ('08', '09')
							OR HomeValue LIKE '%a%'
							OR HomeValue LIKE '%h%')
						AND ResourceID NOT IN ('00', '01', '04', '05', '14F', '14L', '127F', '127L', '135', '168', '173', '174', '175', '176', 
							'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215', '488', '489', '490', '376')
						AND ResourceID NOT LIKE '160%'
						AND ResourceID NOT LIKE '164%'
						AND ResourceID NOT LIKE '169%'
						AND ResourceID NOT LIKE '180%'
						AND ResourceID NOT LIKE '216%'
						AND ResourceID NOT LIKE '217%'
						AND ResourceID NOT LIKE '221%'
						AND ResourceID NOT LIKE '222%'
						AND ResourceID NOT LIKE '223%'
						AND ResourceID NOT LIKE '224%'
						AND ResourceID NOT LIKE '225%'
						AND ResourceID NOT LIKE '226%'
						AND ResourceID NOT LIKE '227%'
						AND ResourceID NOT LIKE '228%'
						AND ResourceID NOT LIKE '229%'
						AND ResourceID NOT LIKE '486%'
						AND ResourceID NOT LIKE '487%')
					OR (@SportType = 5							-- Tennis
						AND SettlementStatusID > 0)
					OR (@SportType = 2							-- Basketball
						AND (LEN(ResourceID) = 2
							OR SettlementStatusID > 0)))
		END
		ELSE IF @SportType IN (6, 9, 50)		-- Volleyball, Badminton, Cricket
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailOS14 WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) = 2
					OR (LEN(ResourceID) = 4 AND @SportType IN (6, 9))
					OR (SettlementStatusID > 0
						AND (@SportType IN (6, 9)
							OR (@SportType = 50 AND ResourceID IN ('9400', '9401', '9442', '9443', '9446', '9447', '9450', '9449', '9452', '9453', 
								'94511', '96151')))))
		END
		ELSE IF @SportType = 43		-- E-Sports
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES14 WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) IN (2, 3) OR SettlementStatusID > 0)
		END
		ELSE IF @SportType = 193
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchID,
				ResourceId,
				Custom1 AS HomeValue,
				Custom2 AS AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
			WHERE MatchID = @MatchId AND SettlementStatusID > 0
		END
	END

	SELECT * FROM @Detail
	ORDER BY MatchId ASC,
		ResourceId ASC
END
GO

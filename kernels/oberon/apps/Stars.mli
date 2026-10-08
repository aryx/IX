(* Six stars that bounce in a viewer (Oberon's Stars): a program with a
 * frame, messages and a task of its own. Its frames answer two
 * messages that only this module knows, declared here and nowhere
 * else: the test of the open messages (plan_system_oberon.md,
 * decision 3).
 *
 * Stars.Open opens a viewer; in its menu, Stars.Step moves its stars a
 * step, Stars.Run installs the task that moves every Stars frame five
 * times a second, Stars.Stop removes it, Stars.Close closes the
 * viewer. Stars.SetPeriod n: the task's period, in turns of the loop. *)

(* move a step *)
exception Step

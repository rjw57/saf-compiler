using Gtk;
using Pango;

namespace Saf {
	class SourceBuffer : Gtk.SourceBuffer {
		private SourceBufferMonitor monitor = null;

		public SourceBuffer() 
		{
			set_language(SourceLanguageManager.get_default().
					get_language("saf"));

			var err_tag = new TextTag("saf:error");
			err_tag.underline = Underline.ERROR;
			tag_table.add(err_tag);

			monitor = new SourceBufferMonitor(this);
		}

		public void load_file(string filename) throws GLib.FileError
		{
			string file_contents = "";
			GLib.FileUtils.get_contents(filename, out file_contents);

			begin_not_undoable_action();
			text = file_contents;
			end_not_undoable_action();
		}
	}
}

// vim:sw=4:ts=4:cindent
